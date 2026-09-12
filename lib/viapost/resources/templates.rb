# frozen_string_literal: true

module ViaPost
  module Resources
    class Templates < Base
      def list(cursor: nil, limit: nil, search: nil)
        request(:get, '/v1/templates', params: { cursor: cursor, limit: limit, search: search })
      end

      def create(name:)
        validate_non_empty_string(name, 'name', max: 256)
        request(:post, '/v1/templates', body: { name: name })
      end

      def retrieve(id) = request(:get, "/v1/templates/#{escape(id)}")
      def delete(id) = request(:delete, "/v1/templates/#{escape(id)}")
      def archive(id) = request(:post, "/v1/templates/#{escape(id)}/archive")
      def duplicate(id) = request(:post, "/v1/templates/#{escape(id)}/duplicate")
      def versions(id) = request(:get, "/v1/templates/#{escape(id)}/versions")

      def version(id, version_id)
        request(:get, "/v1/templates/#{escape(id)}/versions/#{escape(version_id)}")
      end

      def create_asset(id, filename:, content_type:)
        TemplateAssetPolicy.new(
          request(:post, "/v1/templates/#{escape(id)}/assets", body: { filename: filename, content_type: content_type })
        )
      end

      def update_draft(id, content_json:, variables:, subject: UNSET, expected_version_id: nil,
                       expected_updated_at: nil)
        validate_hash(content_json, 'content_json')
        validate_array(variables, 'variables', max: 100)
        validate_pair(expected_version_id, expected_updated_at, 'expected_version_id', 'expected_updated_at')
        body = { content_json: content_json, variables: variables }
        body[:subject] = subject unless subject.equal?(UNSET)
        body[:expected_version_id] = expected_version_id if expected_version_id
        body[:expected_updated_at] = expected_updated_at if expected_updated_at
        request(:patch, "/v1/templates/#{escape(id)}/draft", body: body)
      end

      def preview(id, variables: {})
        validate_hash(variables, 'variables', max: 100)
        request(:post, "/v1/templates/#{escape(id)}/preview", body: { variables: variables })
      end

      def publish(id, expected_version_id: nil, expected_updated_at: nil)
        precondition(:post, "/v1/templates/#{escape(id)}/publish", expected_version_id, expected_updated_at)
      end

      def revert(id, version_id, expected_version_id: nil, expected_updated_at: nil)
        path = "/v1/templates/#{escape(id)}/versions/#{escape(version_id)}/revert"
        precondition(:post, path, expected_version_id, expected_updated_at)
      end

      private

      def compact(hash)
        hash.compact
      end

      def precondition(method, path, expected_version_id, expected_updated_at)
        validate_pair(expected_version_id, expected_updated_at, 'expected_version_id', 'expected_updated_at')
        body = compact(expected_version_id: expected_version_id, expected_updated_at: expected_updated_at)
        request(method, path, body: body.empty? ? nil : body)
      end
    end
  end
end
