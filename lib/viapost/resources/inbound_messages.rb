# frozen_string_literal: true

module ViaPost
  module Resources
    class InboundMessages < Base
      PERIODS = %w[7d 30d].freeze

      def list(cursor: nil, limit: nil, domain_id: nil, search: nil, period: nil, has_attachments: nil)
        unless period.nil? || PERIODS.include?(period)
          raise ValidationError, "period must be one of: #{PERIODS.join(', ')}"
        end

        request(
          :get,
          '/v1/inbound-messages',
          params: {
            cursor: cursor,
            limit: limit,
            domain_id: domain_id,
            search: search,
            period: period,
            has_attachments: has_attachments
          }
        )
      end

      def retrieve(id)
        request(:get, "/v1/inbound-messages/#{escape(id)}")
      end

      def raw(id)
        request(
          :get,
          "/v1/inbound-messages/#{escape(id)}/raw",
          accept: 'message/rfc822',
          response_format: :binary
        )
      end
    end
  end
end
