# frozen_string_literal: true

require 'uri'

module ViaPost
  module Resources
    class Base
      UNSET = Object.new.freeze

      def initialize(client)
        @client = client
      end

      private

      def request(method, path, **options)
        @client.request(method, path, **options)
      end

      def escape(value)
        string = value.to_s
        raise ValidationError, 'path value must not be empty, . or ..' if ['', '.', '..'].include?(string)

        Client.escape_path(string)
      end

      def validate_array(value, name, min: nil, max: nil)
        raise ValidationError, "#{name} must be an Array" unless value.is_a?(Array)
        raise ValidationError, "#{name} must contain at least #{min} item(s)" if min && value.length < min
        raise ValidationError, "#{name} must contain at most #{max} item(s)" if max && value.length > max
      end

      def validate_hash(value, name, max: nil)
        raise ValidationError, "#{name} must be a Hash" unless value.is_a?(Hash)
        raise ValidationError, "#{name} must contain at most #{max} properties" if max && value.length > max
      end

      def validate_non_empty_string(value, name, max: nil)
        valid = value.is_a?(String) && !value.empty? && (!max || value.length <= max)
        raise ValidationError, "#{name} must be a non-empty string#{" up to #{max} characters" if max}" unless valid
      end

      def validate_pair(first, second, first_name, second_name)
        return if first.nil? == second.nil?

        raise ValidationError, "#{first_name} and #{second_name} must be provided together"
      end
    end
  end
end
