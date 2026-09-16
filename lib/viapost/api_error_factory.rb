# frozen_string_literal: true

module ViaPost
  class ApiErrorFactory
    ERROR_CLASSES = {
      400 => BadRequestError,
      401 => AuthenticationError,
      403 => PermissionError,
      404 => NotFoundError,
      409 => ConflictError,
      429 => RateLimitError
    }.freeze

    def initialize(response, api_key)
      @response = response
      @api_key = api_key
    end

    def build(payload)
      detail = payload[:error] if payload.is_a?(Hash)
      detail = {} unless detail.is_a?(Hash)
      secrets = [@api_key]
      collect_sensitive_values(detail, secrets)
      safe_detail = redact(detail, secrets)
      error_class.new(
        message(safe_detail),
        status: @response.status,
        code: safe_detail[:code],
        request_id: safe_detail[:request_id] || redact(header_request_id, secrets),
        retry_after: Float(@response.headers['retry-after'], exception: false),
        details: safe_detail
      )
    end

    private

    def error_class
      ERROR_CLASSES.fetch(@response.status, @response.status >= 500 ? ServerError : APIError)
    end

    def message(detail)
      return detail[:message] unless detail[:message].to_s.empty?

      "ViaPost request failed with HTTP #{@response.status}"
    end

    def header_request_id
      @response.headers['x-request-id'] || @response.headers['x-correlation-id']
    end

    def collect_sensitive_values(value, secrets)
      case value
      when Hash
        value.each do |key, item|
          if sensitive_key?(key)
            collect_strings(item, secrets)
          else
            collect_sensitive_values(item, secrets)
          end
        end
      when Array
        value.each { |item| collect_sensitive_values(item, secrets) }
      end
    end

    def collect_strings(value, secrets)
      case value
      when Hash
        value.each_value { |item| collect_strings(item, secrets) }
      when Array
        value.each { |item| collect_strings(item, secrets) }
      when String
        secrets << value unless value.empty?
      end
    end

    def sensitive_key?(key)
      normalized = key.to_s.downcase.tr('- ', '_')
      %w[secret token password api_key authorization cookie].any? do |name|
        normalized == name || normalized.end_with?("_#{name}")
      end
    end

    def redact(value, secrets)
      case value
      when Hash
        value.to_h do |key, item|
          [key, sensitive_key?(key) ? '[REDACTED]' : redact(item, secrets)]
        end
      when Array
        value.map { |item| redact(item, secrets) }
      when String
        secrets.reduce(value) { |safe, secret| safe.gsub(secret, '[REDACTED]') }
      else
        value
      end
    end
  end
end
