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
    RESPONSE_FORMATS = %i[json binary].freeze
    PROTECTED_HEADERS = %w[
      accept accept-encoding authorization connection content-length content-type cookie host keep-alive
      proxy-authenticate proxy-authorization te trailer transfer-encoding upgrade user-agent
    ].freeze

    attr_reader :configuration, :send_email, :messages, :inbound_messages, :suppressions, :domains, :templates,
                :webhooks, :automations, :usage

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

    def request(method, path, params: {}, body: nil, headers: {}, content_type: 'application/json',
                accept: 'application/json', response_format: :json)
      method = method.to_sym
      request_class = REQUEST_CLASSES.fetch(method) { raise ArgumentError, "unsupported HTTP method: #{method}" }
      unless RESPONSE_FORMATS.include?(response_format)
        raise ArgumentError, "unsupported response format: #{response_format}"
      end

      Timeout.timeout(@configuration.timeout, Timeout::Error) do
        attempts = 0

        loop do
          response = @adapter.perform(
            uri: build_uri(path, params),
            request: build_request(request_class, path, params, body, headers, content_type, accept),
            max_response_bytes: response_limit(response_format),
            max_error_response_bytes: @configuration.max_response_bytes
          )
          if retryable?(method, response.status) && attempts < @configuration.max_retries
            @sleeper.call(retry_delay(response, attempts))
            attempts += 1
            next
          end

          return decode(response, response_format)
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
      @inbound_messages = Resources::InboundMessages.new(self)
      @suppressions = Resources::Suppressions.new(self)
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

    def build_request(request_class, path, params, body, extra_headers, content_type, accept)
      uri = build_uri(path, params)
      validate_header_value(accept, 'accept')
      validate_header_value(content_type, 'content_type') unless body.nil?
      request = request_class.new(uri.request_uri, safe_extra_headers(extra_headers))
      set_protected_headers(request, accept)
      set_body(request, body, content_type)
      request
    end

    def safe_extra_headers(extra_headers)
      connection_tokens = extra_headers.filter_map do |key, value|
        value.to_s.split(',').map { |token| token.strip.downcase } if key.to_s.downcase == 'connection'
      end.flatten
      blocked_headers = PROTECTED_HEADERS + connection_tokens
      extra_headers.reject { |key, _value| blocked_headers.include?(key.to_s.downcase) }
    end

    def set_protected_headers(request, accept)
      request['Authorization'] = "Bearer #{@configuration.api_key}"
      request['Accept'] = accept
      request['Accept-Encoding'] = 'identity'
      request['User-Agent'] = "viapost-ruby/#{VERSION}"
    end

    def set_body(request, body, content_type)
      return if body.nil?

      request['Content-Type'] = content_type
      request.body = content_type == 'application/json' ? JSON.generate(body) : body.to_s
    end

    def validate_header_value(value, name)
      valid = value.is_a?(String) && !value.empty? && !value.match?(/[[:cntrl:]]/)
      raise ArgumentError, "#{name} must be a non-empty header value without control characters" unless valid
    end

    def response_limit(response_format)
      response_format == :binary ? @configuration.max_raw_response_bytes : @configuration.max_response_bytes
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

    def decode(response, response_format)
      return nil if [204, 205].include?(response.status)

      if response.status.between?(200, 299)
        return response.body.dup.force_encoding(Encoding::BINARY) if response_format == :binary

        return parse_json(response.body)
      end

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
