# frozen_string_literal: true

module ViaPost
  module Resources
    class Domains < Base
      def list = request(:get, '/v1/domains')
      def create(name:) = request(:post, '/v1/domains', body: { name: name })
      def retrieve(id) = request(:get, "/v1/domains/#{escape(id)}")
      def delete(id) = request(:delete, "/v1/domains/#{escape(id)}")
      def rotate_dkim(id) = request(:post, "/v1/domains/#{escape(id)}/dkim/rotate")
      def dns(id) = request(:get, "/v1/domains/#{escape(id)}/dns")
      def verify(id) = request(:post, "/v1/domains/#{escape(id)}/verify")
    end
  end
end
