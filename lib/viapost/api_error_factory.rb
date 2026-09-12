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
      safe_detail = redact(detail)
      error_class.new(
        message(safe_detail),
        status: @response.status,
        code: safe_detail[:code],
        request_id: safe_detail[:request_id] || redact(header_request_id),
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

    def redact(value)
      case value
      when Hash
        value.transform_values { |item| redact(item) }
      when Array
        value.map { |item| redact(item) }
      when String
        value.gsub(@api_key, '[REDACTED]')
      else
        value
      end
    end
  end
end
