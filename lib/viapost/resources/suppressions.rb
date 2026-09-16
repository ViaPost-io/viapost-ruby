# frozen_string_literal: true

module ViaPost
  module Resources
    class Suppressions < Base
      CREATE_REASONS = %w[manual invalid_address].freeze
      STATES = %w[active expired released all].freeze
      ORIGINS = %w[manual import automatic].freeze
      MAX_CSV_BYTES = 2 * 1024 * 1024

      def list(cursor: nil, limit: nil, search: nil, reason: nil, state: nil, origin: nil)
        validate_filters(limit: limit, state: state, origin: origin)
        request(
          :get,
          '/v1/suppressions',
          params: { cursor: cursor, limit: limit, search: search, reason: reason, state: state, origin: origin }
        )
      end

      def create(email:, reason:, expires_at: nil, note: nil)
        validate_non_empty_string(email, 'email', max: 254)
        unless CREATE_REASONS.include?(reason)
          raise ValidationError, "reason must be one of: #{CREATE_REASONS.join(', ')}"
        end
        if !note.nil? && (!note.is_a?(String) || note.length > 500)
          raise ValidationError, 'note must be a string up to 500 characters or nil'
        end

        request(
          :post,
          '/v1/suppressions',
          body: { email: email, reason: reason, expires_at: expires_at, note: note }.compact
        )
      end

      def retrieve(id, history_cursor: nil, history_limit: nil)
        validate_integer_range(history_limit, 'history_limit', min: 1, max: 100) if history_limit
        request(
          :get,
          "/v1/suppressions/#{escape(id)}",
          params: { history_cursor: history_cursor, history_limit: history_limit }
        )
      end

      def release(id, expected_version:, acknowledge:, justification:)
        validate_integer_range(expected_version, 'expected_version', min: 1)
        raise ValidationError, 'acknowledge must be true' unless acknowledge == true
        unless justification.is_a?(String) && justification.length.between?(10, 500)
          raise ValidationError, 'justification must be between 10 and 500 characters'
        end

        request(
          :post,
          "/v1/suppressions/#{escape(id)}/release",
          body: { expected_version: expected_version, acknowledge: true, justification: justification }
        )
      end

      def import_csv(csv)
        raise ValidationError, 'csv must be a String' unless csv.is_a?(String)
        raise ValidationError, "csv must not exceed #{MAX_CSV_BYTES} bytes" if csv.bytesize > MAX_CSV_BYTES

        request(:post, '/v1/suppressions/import', body: csv, content_type: 'text/csv')
      end

      def export_csv(search: nil, reason: nil, state: nil, origin: nil)
        validate_filters(limit: nil, state: state, origin: origin)
        request(
          :get,
          '/v1/suppressions/export',
          params: { search: search, reason: reason, state: state, origin: origin },
          accept: 'text/csv',
          response_format: :binary
        )
      end

      private

      def validate_filters(limit:, state:, origin:)
        validate_integer_range(limit, 'limit', min: 1, max: 50) if limit
        raise ValidationError, "state must be one of: #{STATES.join(', ')}" if state && !STATES.include?(state)
        raise ValidationError, "origin must be one of: #{ORIGINS.join(', ')}" if origin && !ORIGINS.include?(origin)
      end
    end
  end
end
