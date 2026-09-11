# frozen_string_literal: true

module ViaPost
  module Resources
    class Messages < Base
      def list(cursor: nil, limit: nil, status: nil, search: nil, period: nil, api_key_id: nil)
        request(:get, '/v1/messages', params: compact_params(binding))
      end

      def retrieve(id)
        request(:get, "/v1/messages/#{escape(id)}")
      end

      def events(id)
        request(:get, "/v1/messages/#{escape(id)}/events")
      end

      def engagement(days: nil)
        request(:get, '/v1/messages/engagement', params: { days: days })
      end

      def metrics(days: nil, domain_id: nil)
        request(:get, '/v1/messages/metrics', params: { days: days, domain_id: domain_id })
      end

      def timeseries(days: nil)
        request(:get, '/v1/messages/timeseries', params: { days: days })
      end

      private

      def compact_params(context)
        context.local_variables.to_h { |name| [name, context.local_variable_get(name)] }
      end
    end
  end
end
