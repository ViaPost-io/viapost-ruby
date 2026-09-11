# frozen_string_literal: true

require 'json'
require 'net/http'
require 'time'
require 'timeout'
require 'uri'

module ViaPost
  class Client
    REQUEST_CLASSES = {
      get: Net::HTTP::Get,
      head: Net::HTTP::Head,
      post: Net::HTTP::Post,
      patch: Net::HTTP::Patch,
      delete: Net::HTTP::Delete
    }.freeze
    attr_reader :configuration, :send_email, :messages, :domains, :templates, :webhooks, :automations, :usage

    def initialize(api_key:, adapter: nil, sleeper: Kernel.method(:sleep), **options)
      @configuration = Configuration.new(api_key: api_key, **options)
      @adapter = adapter || NetHttpAdapter.new(
        open_timeout: @configuration.open_timeout,
        read_timeout: @configuration.read_timeout,
        write_timeout: @configuration.write_timeout
      )
      @sleeper = sleeper
      initialize_resources
    end

    def request(method, path, params: {}, body: nil, headers: {})
      method = method.to_sym
      request_class = REQUEST_CLASSES.fetch(method) { raise ArgumentError, "unsupported HTTP method: #{method}" }
      Timeout.timeout(@configuration.timeout, Timeout::Error) do
        attempts = 0

        loop do
          response = @adapter.perform(
            uri: build_uri(path, params),
            request: build_request(request_class, path, params, body, headers),
            max_response_bytes: @configuration.max_response_bytes
          )
          if retryable?(method, response.status) && attempts < @configuration.max_retries
            @sleeper.call(retry_delay(response, attempts))
            attempts += 1
            next
          end

          return decode(response)
        end
      end
    rescue Timeout::Error
      raise TimeoutError, "ViaPost request exceeded the #{@configuration.timeout}-second operation timeout"
    end

    def inspect
      "#<#{self.class} base_url=#{@configuration.base_uri} api_key=[REDACTED]>"
    end

    def self.escape_path(value)
      URI.encode_www_form_component(value.to_s).gsub('+', '%20')
    end

    private

    def initialize_resources
      @send_email = Resources::Send.new(self)
      @messages = Resources::Messages.new(self)
      @domains = Resources::Domains.new(self)
      @templates = Resources::Templates.new(self)
      @webhooks = Resources::Webhooks.new(self)
      @automations = Resources::Automations.new(self)
      @usage = Resources::Usage.new(self)
    end

    def build_uri(path, params)
      uri = @configuration.base_uri.dup
      uri.path = "#{uri.path}#{path}"
      filtered = params.compact
      uri.query = URI.encode_www_form(filtered) unless filtered.empty?
      uri
    end

    def build_request(request_class, path, params, body, extra_headers)
      uri = build_uri(path, params)
      headers = extra_headers.reject { |key, _value| %w[authorization cookie].include?(key.to_s.downcase) }.merge(
        'Authorization' => "Bearer #{@configuration.api_key}",
        'Accept' => 'application/json',
        'Accept-Encoding' => 'identity',
        'User-Agent' => "viapost-ruby/#{VERSION}"
      )
      request = request_class.new(uri.request_uri, headers)
      unless body.nil?
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(body)
      end
      request
    end

    def retryable?(method, status)
      %i[get head].include?(method) && (status == 429 || status >= 500)
    end

    def retry_delay(response, attempts)
      header = response.headers['retry-after']
      seconds = Float(header, exception: false) if header
      return seconds.clamp(0, 60.0) if seconds&.finite?

      if header
        parsed = begin
          Time.httpdate(header)
        rescue StandardError
          nil
        end
        return (parsed - Time.now).clamp(0, 60.0) if parsed
      end

      [0.25 * (2**attempts), 2.0].min
    end

    def decode(response)
      return nil if [204, 205].include?(response.status)

      return parse_json(response.body) if response.status.between?(200, 299)

      raise_api_error(response, parse_error_json(response.body))
    end

    def parse_json(body)
      return {} if body.nil? || body.empty?

      JSON.parse(body, symbolize_names: true)
    rescue JSON::ParserError
      raise DecodeError, 'ViaPost returned invalid JSON'
    end

    def parse_error_json(body)
      parse_json(body)
    rescue DecodeError
      {}
    end

    def raise_api_error(response, payload)
      raise ApiErrorFactory.new(response, @configuration.api_key).build(payload)
    end
  end
end
