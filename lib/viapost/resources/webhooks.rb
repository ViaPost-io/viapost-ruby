# frozen_string_literal: true

require 'ipaddr'
require 'socket'
require 'uri'

module ViaPost
  module Resources
    class Webhooks < Base
      NON_PUBLIC_NETWORKS = %w[
        0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
        192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24
        203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 ::/128 ::1/128 fc00::/7 fe80::/10
        ::/96 2001:db8::/32 ff00::/8
      ].map { |network| IPAddr.new(network) }.freeze

      def list = request(:get, '/v1/webhooks')

      def create(url:, event_types:)
        validate_public_https_url(url)

        validate_array(event_types, 'event_types', min: 1)
        CreateWebhookResponse.new(
          request(:post, '/v1/webhooks', body: { url: url, event_types: event_types })
        )
      end

      def delete(id) = request(:delete, "/v1/webhooks/#{escape(id)}")

      def update(id, expected_version:, enabled: UNSET, event_types: UNSET, max_attempts: UNSET)
        validate_integer_range(expected_version, 'expected_version', min: 1)
        attributes = webhook_attributes(enabled, event_types, max_attempts)
        raise ValidationError, 'at least one webhook field must be provided' if attributes.empty?

        validate_webhook_attributes(attributes)
        request(:patch, "/v1/webhooks/#{escape(id)}", body: attributes.merge(expected_version: expected_version))
      end

      def deliveries(id, cursor: nil, limit: nil, status: nil, event_type: nil)
        validate_integer_range(limit, 'limit', min: 1, max: 100) if limit
        request(
          :get,
          "/v1/webhooks/#{escape(id)}/deliveries",
          params: { cursor: cursor, limit: limit, status: status, event_type: event_type }
        )
      end

      def delivery(id, delivery_id)
        request(:get, "/v1/webhooks/#{escape(id)}/deliveries/#{escape(delivery_id)}")
      end

      def replay(id, delivery_id, idempotency_key:)
        idempotent_post(
          "/v1/webhooks/#{escape(id)}/deliveries/#{escape(delivery_id)}/replay",
          idempotency_key
        )
      end

      def rotate_secret(id, idempotency_key:)
        RotateWebhookSecretResponse.new(
          idempotent_post("/v1/webhooks/#{escape(id)}/secret/rotate", idempotency_key)
        )
      end

      def test(id, idempotency_key:)
        idempotent_post("/v1/webhooks/#{escape(id)}/test", idempotency_key)
      end

      private

      def validate_public_https_url(value)
        uri, hostname = parse_webhook_uri(value)
        addresses = resolved_addresses(hostname, uri.port)
        raise ValidationError, 'url must resolve only to public addresses' unless public_addresses?(addresses)
      rescue URI::InvalidURIError, IPAddr::InvalidAddressError, SocketError
        raise ValidationError, 'url must be a valid public HTTPS URL'
      end

      def parse_webhook_uri(value)
        uri = URI.parse(value.to_s)
        hostname = uri.hostname&.downcase&.delete_suffix('.')
        validate_webhook_origin!(uri, hostname)

        [uri, hostname]
      end

      def validate_webhook_origin!(uri, hostname)
        valid = uri.is_a?(URI::HTTPS) && hostname && !uri.userinfo && !uri.fragment
        raise ValidationError, 'url must be an absolute public HTTPS URL' unless valid
        return unless hostname == 'localhost' || hostname.end_with?('.localhost')

        raise ValidationError, 'url must resolve only to public addresses'
      end

      def public_addresses?(addresses)
        return false if addresses.empty?

        addresses.none? do |address|
          normalized = address.ipv4_mapped? ? address.native : address
          NON_PUBLIC_NETWORKS.any? { |network| network.include?(normalized) }
        end
      end

      def resolved_addresses(hostname, port)
        literal = IPAddr.new(hostname)
        [literal]
      rescue IPAddr::InvalidAddressError
        Addrinfo.getaddrinfo(hostname, port, nil, :STREAM).map { |entry| IPAddr.new(entry.ip_address) }.uniq
      end

      def webhook_attributes(enabled, event_types, max_attempts)
        { enabled: enabled, event_types: event_types, max_attempts: max_attempts }.reject do |_key, value|
          value.equal?(UNSET)
        end
      end

      def validate_webhook_attributes(attributes)
        validate_event_types(attributes[:event_types]) if attributes.key?(:event_types)
        if attributes.key?(:max_attempts)
          validate_integer_range(attributes[:max_attempts], 'max_attempts', min: 1, max: 20)
        end
        return unless attributes.key?(:enabled) && ![true, false].include?(attributes[:enabled])

        raise ValidationError, 'enabled must be true or false'
      end

      def validate_event_types(event_types)
        validate_array(event_types, 'event_types', min: 1)
        raise ValidationError, 'event_types must be unique' unless event_types.uniq.length == event_types.length
      end

      def idempotent_post(path, idempotency_key)
        validate_idempotency_key(idempotency_key)
        request(:post, path, body: {}, headers: { 'Idempotency-Key' => idempotency_key })
      end
    end
  end
end
