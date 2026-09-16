# frozen_string_literal: true

module ViaPost
  class SensitiveResponse
    include Enumerable

    def initialize(values, sensitive_keys:)
      @values = values.dup.freeze
      @sensitive_keys = sensitive_keys.map(&:to_sym).freeze
      freeze
    end

    def [](key) = redacted[key]
    def fetch(...) = redacted.fetch(...)
    def key?(key) = @values.key?(key)
    def keys = @values.keys
    def each(&) = redacted.each(&)

    def inspect = "#<#{self.class} #{redacted.inspect}>"
    alias to_s inspect

    def pretty_print(printer) = printer.text(inspect)
    def to_h = redacted
    def as_json(*) = redacted
    def to_json(*arguments) = redacted.to_json(*arguments)
    def marshal_dump = redacted
    def encode_with(coder) = coder.represent_map(nil, redacted)

    private

    def redacted
      @values.each_with_object({}) do |(key, value), output|
        output[key] = @sensitive_keys.include?(key.to_sym) ? '[REDACTED]' : value
      end
    end

    def reveal(key) = @values.fetch(key)
  end

  class CreateWebhookResponse < SensitiveResponse
    def initialize(values) = super(values, sensitive_keys: [:secret])
    def secret = reveal(:secret)
  end

  class TemplateAssetPolicy < SensitiveResponse
    def initialize(values) = super(values, sensitive_keys: %i[upload_url upload_fields])
    def upload_url = reveal(:upload_url)
    def upload_fields = reveal(:upload_fields)
  end

  class RotateWebhookSecretResponse < SensitiveResponse
    def initialize(values) = super(values, sensitive_keys: [:secret])
    def secret = reveal(:secret)
  end
end
