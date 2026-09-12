# frozen_string_literal: true

require_relative 'test_helper'

class SensitiveResponseTest < Minitest::Test
  def test_webhook_secret_remains_explicitly_accessible_but_is_redacted_from_inspection
    secret = 'whsec_never_log_this'
    adapter = FakeAdapter.new(response(body: JSON.generate(endpoint: {}, secret: secret)))

    result = client(adapter: adapter).webhooks.create(
      url: 'https://example.com/events', event_types: ['message.delivered']
    )

    assert_equal secret, result[:secret]
    assert_instance_of ViaPost::CreateWebhookResponse, result
    refute_includes result.inspect, secret
    assert_includes result.inspect, '[REDACTED]'
  end

  def test_temporary_asset_credentials_are_redacted_from_inspection
    adapter = FakeAdapter.new(response(body: JSON.generate(
      upload_url: 'https://storage.test/upload?signature=never-log-this',
      upload_fields: { policy: 'signed-policy' },
      asset_url: 'https://cdn.test/public.png'
    )))

    result = client(adapter: adapter).templates.create_asset(
      'template-id', filename: 'image.png', content_type: 'image/png'
    )

    assert_instance_of ViaPost::TemplateAssetPolicy, result
    assert_equal 'signed-policy', result[:upload_fields][:policy]
    refute_includes result.inspect, 'never-log-this'
    refute_includes result.inspect, 'signed-policy'
    assert_includes result.inspect, '[REDACTED]'
  end
end
