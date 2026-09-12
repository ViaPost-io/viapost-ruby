# frozen_string_literal: true

module ViaPost
  class SensitiveResponse < Hash
    def initialize(values, sensitive_keys:)
      super()
      update(values)
      @sensitive_keys = sensitive_keys.freeze
    end

    def inspect = "#<#{self.class} #{redacted.inspect}>"
    alias to_s inspect

    def pretty_print(printer) = printer.text(inspect)
    def as_json(*) = redacted
    def to_json(*arguments) = redacted.to_json(*arguments)

    private

    def redacted
      each_with_object({}) do |(key, value), output|
        output[key] = @sensitive_keys.include?(key.to_sym) ? '[REDACTED]' : value
      end
    end
  end

  class CreateWebhookResponse < SensitiveResponse
    def initialize(values) = super(values, sensitive_keys: [:secret])
  end

  class TemplateAssetPolicy < SensitiveResponse
    def initialize(values) = super(values, sensitive_keys: %i[upload_url upload_fields])
  end
end
