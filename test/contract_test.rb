# frozen_string_literal: true

require 'digest'
require_relative 'test_helper'

class ContractTest < Minitest::Test
  CONTRACT = File.expand_path('../openapi/public.yaml', __dir__)

  def test_vendored_contract_sha
    assert_equal 'd1f223342ad1ca326ba716af6e508c78594e1b108958cce2ec4a1efd31a9773a', Digest::SHA256.file(CONTRACT).hexdigest
  end

  def test_vendored_contract_contains_beta_routes
    contract = File.read(CONTRACT)

    %w[/v1/send /v1/messages /v1/domains /v1/templates /v1/webhooks /v1/automations /v1/usage].each do |route|
      assert_includes contract, "  #{route}:"
    end
  end
end
