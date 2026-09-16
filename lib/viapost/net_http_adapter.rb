# frozen_string_literal: true

require 'net/http'
require 'openssl'

module ViaPost
  TransportResponse = Struct.new(:status, :headers, :body, keyword_init: true)

  class NetHttpAdapter
    def initialize(open_timeout:, read_timeout:, write_timeout:, http_factory: nil)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @write_timeout = write_timeout
      @http_factory = http_factory || ->(uri) { Net::HTTP.new(uri.host, uri.port) }
    end

    def perform(uri:, request:, max_response_bytes:, max_error_response_bytes:)
      http = @http_factory.call(uri)
      configure(http, uri)
      response = nil
      body = String.new(encoding: Encoding::BINARY)

      http.request(request) do |raw_response|
        response = raw_response
        response_limit = raw_response.code.to_i.between?(200, 299) ? max_response_bytes : max_error_response_bytes
        raw_response.read_body do |chunk|
          if body.bytesize + chunk.bytesize > response_limit
            raise ResponseTooLargeError,
                  "ViaPost response exceeded #{response_limit} bytes"
          end

          body << chunk
        end
      end

      TransportResponse.new(status: response.code.to_i, headers: normalized_headers(response), body: body)
    rescue Timeout::Error
      raise TimeoutError, 'ViaPost request timed out'
    rescue ResponseTooLargeError
      raise
    rescue StandardError
      raise ConnectionError, 'Unable to connect to ViaPost'
    end

    private

    def configure(http, uri)
      http.use_ssl = uri.scheme == 'https'
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER if uri.scheme == 'https'
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http.write_timeout = @write_timeout if http.respond_to?(:write_timeout=)
    end

    def normalized_headers(response)
      response.each_header.to_h.transform_keys(&:downcase)
    end
  end
end
