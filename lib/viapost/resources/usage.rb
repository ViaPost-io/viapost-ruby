# frozen_string_literal: true

module ViaPost
  module Resources
    class Usage < Base
      def retrieve = request(:get, '/v1/usage')
    end
  end
end
