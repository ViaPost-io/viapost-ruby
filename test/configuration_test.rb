# frozen_string_literal: true

require_relative 'test_helper'

class ConfigurationTest < Minitest::Test
  def test_rejects_blank_api_key
    assert_raises(ViaPost::ConfigurationError) { ViaPost::Client.new(api_key: ' ') }
  end

  def test_rejects_api_keys_with_whitespace_or_control_characters
    assert_raises(ViaPost::ConfigurationError) { ViaPost::Client.new(api_key: ' secret') }
    assert_raises(ViaPost::ConfigurationError) { ViaPost::Client.new(api_key: "secret\r\nInjected: value") }
  end

  def test_requires_https_outside_loopback
    error = assert_raises(ViaPost::ConfigurationError) do
      ViaPost::Client.new(api_key: 'secret', base_url: 'http://api.example.com')
    end

    assert_match(/HTTPS/, error.message)
  end

  def test_allows_http_for_loopback_only
    configured = ViaPost::Client.new(api_key: 'secret', base_url: 'http://127.0.0.1:15080')

    assert_instance_of ViaPost::Client, configured
  end

  def test_enforces_hard_response_and_retry_caps
    assert_raises(ViaPost::ConfigurationError) do
      ViaPost::Client.new(api_key: 'secret', max_response_bytes: (8 * 1024 * 1024) + 1)
    end
    assert_raises(ViaPost::ConfigurationError) { ViaPost::Client.new(api_key: 'secret', max_retries: 6) }
  end

  def test_inspect_redacts_api_key
    key = +'vp_live_super_secret'
    configured = ViaPost::Client.new(api_key: key)
    key.replace('changed')

    refute_includes configured.inspect, 'vp_live_super_secret'
    assert_raises(FrozenError) { configured.configuration.base_uri.scheme = 'http' }
  end
end
