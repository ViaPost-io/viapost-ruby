# frozen_string_literal: true

module ViaPost
  module Resources
    class Webhooks < Base
      def list = request(:get, '/v1/webhooks')

      def create(url:, event_types:)
        uri = URI.parse(url.to_s)
        raise ValidationError, 'url must use HTTP or HTTPS' unless uri.host && %w[http https].include?(uri.scheme)

        validate_array(event_types, 'event_types', min: 1)
        CreateWebhookResponse.new(
          request(:post, '/v1/webhooks', body: { url: url, event_types: event_types })
        )
      rescue URI::InvalidURIError
        raise ValidationError, 'url must be a valid HTTP(S) URL'
      end

      def delete(id) = request(:delete, "/v1/webhooks/#{escape(id)}")
    end
  end
end
