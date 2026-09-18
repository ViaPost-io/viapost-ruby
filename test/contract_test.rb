# frozen_string_literal: true

require 'digest'
require 'json'
require_relative 'test_helper'

class ContractTest < Minitest::Test
  CONTRACT = File.expand_path('../openapi/public.yaml', __dir__)

  def test_vendored_contract_sha
    assert_equal 'c5d5ae1d85e61b4e14e09351b14146465ce357075d2ed5fe4e034f6ff6693dc1', Digest::SHA256.file(CONTRACT).hexdigest
  end

  def test_vendored_contract_contains_beta_routes
    contract = File.read(CONTRACT)

    %w[/v1/send /v1/messages /v1/inbound-messages /v1/suppressions /v1/domains /v1/templates
       /v1/webhooks /v1/automations /v1/usage].each do |route|
      assert_includes contract, "  #{route}:"
    end
  end

  def test_contract_source_metadata_is_complete_and_matches_snapshot
    metadata = JSON.parse(File.read(File.expand_path('../docs/openapi-source.json', __dir__)))

    assert_equal 'https://docs.viapost.io/openapi/public.yaml', metadata.fetch('url')
    assert_equal Digest::SHA256.file(CONTRACT).hexdigest, metadata.fetch('sha256')
    assert_match(/\A[0-9a-f]{40}\z/, metadata.fetch('source_commit'))
  end
end
