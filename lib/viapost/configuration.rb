# frozen_string_literal: true

require 'ipaddr'
require 'uri'

module ViaPost
  class Configuration
    DEFAULT_BASE_URL = 'https://api.viapost.io'
    DEFAULT_MAX_RESPONSE_BYTES = 8 * 1024 * 1024

    attr_reader :api_key, :base_uri, :timeout, :open_timeout, :read_timeout, :write_timeout,
                :max_response_bytes, :max_retries

    def initialize(api_key:, base_url: DEFAULT_BASE_URL, timeout: 60, open_timeout: 5, read_timeout: 30,
                   write_timeout: 30, max_response_bytes: DEFAULT_MAX_RESPONSE_BYTES, max_retries: 2)
      @api_key = validate_api_key(api_key)
      @base_uri = validate_base_url(base_url)
      @timeout = positive_number(timeout, 'timeout')
      @open_timeout = positive_number(open_timeout, 'open_timeout')
      @read_timeout = positive_number(read_timeout, 'read_timeout')
      @write_timeout = positive_number(write_timeout, 'write_timeout')
      @max_response_bytes = bounded_response_size(max_response_bytes)
      @max_retries = bounded_retries(max_retries)
    end

    def inspect
      "#<#{self.class} api_key=[REDACTED] base_url=#{base_uri}>"
    end

    private

    def validate_api_key(value)
      return value.dup.freeze if safe_api_key?(value)

      raise ConfigurationError,
            'api_key must be non-empty and contain no surrounding whitespace or control characters'
    end

    def safe_api_key?(value)
      value.is_a?(String) && value == value.strip && !value.empty? && !value.match?(/[[:cntrl:]]/)
    end

    def validate_base_url(value)
      uri = URI.parse(value.to_s)
      valid_origin = uri.host && !uri.userinfo && !uri.query && !uri.fragment
      raise ConfigurationError, 'base_url must be an absolute HTTP(S) origin' unless valid_origin
      unless uri.scheme == 'https' || loopback?(uri)
        raise ConfigurationError,
              'base_url must use HTTPS outside loopback'
      end

      uri.path = uri.path.to_s.chomp('/')
      uri.freeze
    rescue URI::InvalidURIError
      raise ConfigurationError, 'base_url must be a valid URL'
    end

    def loopback?(uri)
      return false unless uri.scheme == 'http'
      return true if uri.host == 'localhost'

      IPAddr.new(uri.host).loopback?
    rescue IPAddr::InvalidAddressError
      false
    end

    def positive_number(value, name)
      return value if value.is_a?(Numeric) && value.positive?

      raise ConfigurationError, "#{name} must be positive"
    end

    def positive_integer(value, name)
      return value if value.is_a?(Integer) && value.positive?

      raise ConfigurationError, "#{name} must be a positive integer"
    end

    def non_negative_integer(value, name)
      return value if value.is_a?(Integer) && !value.negative?

      raise ConfigurationError, "#{name} must be a non-negative integer"
    end

    def bounded_response_size(value)
      size = positive_integer(value, 'max_response_bytes')
      return size if size <= DEFAULT_MAX_RESPONSE_BYTES

      raise ConfigurationError, "max_response_bytes cannot exceed #{DEFAULT_MAX_RESPONSE_BYTES}"
    end

    def bounded_retries(value)
      retries = non_negative_integer(value, 'max_retries')
      return retries if retries <= 5

      raise ConfigurationError, 'max_retries cannot exceed 5'
    end
  end
end
