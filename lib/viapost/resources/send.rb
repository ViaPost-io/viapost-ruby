# frozen_string_literal: true

module ViaPost
  module Resources
    class Send < Base
      ALLOWED_ATTRIBUTES = %i[
        from_name reply_to cc bcc subject html text stream tags metadata template_id variables attachments
      ].freeze

      def create(from:, to:, idempotency_key: nil, **attributes)
        validate_request(from, to, idempotency_key, attributes)

        headers = idempotency_key ? { 'Idempotency-Key' => idempotency_key } : {}
        request(:post, '/v1/send', body: attributes.merge(from: from, to: to), headers: headers)
      end

      private

      def validate_request(from, to, idempotency_key, attributes)
        unknown = attributes.keys - ALLOWED_ATTRIBUTES
        raise ValidationError, "unknown send attribute(s): #{unknown.join(', ')}" unless unknown.empty?

        validate_non_empty_string(from, 'from')
        validate_array(to, 'to', min: 1, max: 50)
        validate_optional_collections(attributes)
        validate_idempotency_key(idempotency_key)
      end

      def validate_optional_collections(attributes)
        validate_array(attributes[:cc], 'cc', max: 50) if attributes.key?(:cc)
        validate_array(attributes[:bcc], 'bcc', max: 50) if attributes.key?(:bcc)
        validate_hash(attributes[:variables], 'variables', max: 100) if attributes.key?(:variables)
        validate_array(attributes[:attachments], 'attachments', max: 10) if attributes.key?(:attachments)
      end

      def validate_idempotency_key(idempotency_key)
        return unless idempotency_key

        valid = idempotency_key.is_a?(String) && idempotency_key.bytesize.between?(1, 255) &&
                idempotency_key.match?(/\A[!-~]+\z/)
        raise ValidationError, 'idempotency_key must be 1-255 visible ASCII bytes' unless valid
      end
    end
  end
end
