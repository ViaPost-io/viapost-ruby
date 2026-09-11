# frozen_string_literal: true

module ViaPost
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ValidationError < Error; end
  class ConnectionError < Error; end
  class TimeoutError < ConnectionError; end
  class DecodeError < Error; end
  class ResponseTooLargeError < Error; end

  class APIError < Error
    attr_reader :status, :code, :request_id, :retry_after, :details

    def initialize(message, status:, code: nil, request_id: nil, retry_after: nil, details: nil)
      super(message)
      @status = status
      @code = code
      @request_id = request_id
      @retry_after = retry_after
      @details = details
    end
  end

  class BadRequestError < APIError; end
  class AuthenticationError < APIError; end
  class PermissionError < APIError; end
  class NotFoundError < APIError; end
  class ConflictError < APIError; end
  class RateLimitError < APIError; end
  class ServerError < APIError; end
end
