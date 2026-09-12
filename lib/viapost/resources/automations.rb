# frozen_string_literal: true

module ViaPost
  module Resources
    class Automations < Base
      def list(status: nil, search: nil)
        request(:get, '/v1/automations', params: { status: status, search: search })
      end

      def create(name:)
        validate_non_empty_string(name, 'name')
        request(:post, '/v1/automations', body: { name: name })
      end

      def retrieve(id) = request(:get, "/v1/automations/#{escape(id)}")
      def delete(id) = request(:delete, "/v1/automations/#{escape(id)}")
      def activate(id) = request(:post, "/v1/automations/#{escape(id)}/activate")
      def disable(id) = request(:post, "/v1/automations/#{escape(id)}/disable")
      def duplicate(id) = request(:post, "/v1/automations/#{escape(id)}/duplicate")

      def rename(id, name:)
        validate_non_empty_string(name, 'name')
        request(:patch, "/v1/automations/#{escape(id)}", body: { name: name })
      end

      def update_draft(id, graph:)
        validate_hash(graph, 'graph')
        request(:patch, "/v1/automations/#{escape(id)}/draft", body: { graph: graph })
      end

      def runs(id, cursor: nil, limit: nil, status: nil)
        if limit && (!limit.is_a?(Integer) || limit < 1 || limit > 200)
          raise ValidationError, 'limit must be between 1 and 200'
        end

        request(:get, "/v1/automations/#{escape(id)}/runs", params: { cursor: cursor, limit: limit, status: status })
      end

      def run(id, run_id)
        request(:get, "/v1/automations/#{escape(id)}/runs/#{escape(run_id)}")
      end

      def cancel_run(id, run_id)
        request(:post, "/v1/automations/#{escape(id)}/runs/#{escape(run_id)}/cancel")
      end
    end
  end
end
