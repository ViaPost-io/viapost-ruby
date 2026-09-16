# frozen_string_literal: true

require_relative 'test_helper'

class ResourcesTest < Minitest::Test
  INVALID_WEBHOOK_URLS = [
    'http://example.com/events', 'https://user@example.com/events',
    'https://example.com/events#fragment', 'https://localhost/events',
    'https://service.localhost/events', 'https://127.0.0.1/events', 'https://10.0.0.1/events',
    'https://169.254.1.1/events', 'https://0.0.0.0/events', 'https://[::1]/events',
    'https://[fe80::1]/events', 'https://[fc00::1]/events', 'https://[::ffff:127.0.0.1]/events',
    'https://[::127.0.0.1]/events'
  ].freeze

  def setup
    @adapter = FakeAdapter.new(Array.new(30) { response })
    @client = client(adapter: @adapter)
  end

  def test_exposes_all_beta_resources
    assert_instance_of ViaPost::Resources::Send, @client.send_email
    assert_instance_of ViaPost::Resources::Messages, @client.messages
    assert_instance_of ViaPost::Resources::Domains, @client.domains
    assert_instance_of ViaPost::Resources::Templates, @client.templates
    assert_instance_of ViaPost::Resources::Webhooks, @client.webhooks
    assert_instance_of ViaPost::Resources::Automations, @client.automations
    assert_instance_of ViaPost::Resources::Usage, @client.usage
    assert_instance_of ViaPost::Resources::InboundMessages, @client.inbound_messages
    assert_instance_of ViaPost::Resources::Suppressions, @client.suppressions
  end

  def test_send_adds_idempotency_header_and_body
    @client.send_email.create(
      from: 'hello@example.com', to: ['dev@example.com'], subject: 'Olá', idempotency_key: 'order-42'
    )
    call = @adapter.calls.last

    assert_equal '/v1/send', call[:uri].path
    assert_equal 'order-42', call[:request]['Idempotency-Key']
    assert_equal 'Olá', JSON.parse(call[:request].body).fetch('subject')
  end

  def test_send_validates_contract_limits_before_network
    assert_raises(ViaPost::ValidationError) { @client.send_email.create(from: 'a', to: []) }
    assert_raises(ViaPost::ValidationError) { @client.send_email.create(from: 'a', to: Array.new(51, 'x')) }
    assert_raises(ViaPost::ValidationError) do
      @client.send_email.create(from: 'a', to: ['x'], variables: 101.times.to_h { |i| [i, i] })
    end
    assert_raises(ViaPost::ValidationError) do
      @client.send_email.create(from: 'a', to: ['x'], attachments: Array.new(11, {}))
    end
    assert_raises(ViaPost::ValidationError) do
      @client.send_email.create(from: 'a', to: ['x'], idempotency_key: 'x' * 256)
    end
    assert_raises(ViaPost::ValidationError) do
      @client.send_email.create(from: 'a', to: ['x'], idempotency_key: "unsafe\r\nHeader: value")
    end
    assert_raises(ViaPost::ValidationError) do
      @client.send_email.create(from: 'a', to: ['x'], idempotency_key: 'not header safe')
    end
    assert_raises(ViaPost::ValidationError) do
      @client.send_email.create(from: 'a', to: ['x'], unexpected: true)
    end
    assert_empty @adapter.calls
  end

  def test_message_routes_and_pagination
    @client.messages.list(cursor: 'cursor', limit: 20, status: 'sent')
    @client.messages.retrieve('a/b')
    @client.messages.events('id')
    @client.messages.engagement(days: 7)
    @client.messages.metrics(days: 14, domain_id: 'domain')
    @client.messages.timeseries(days: 30)
    @client.messages.raw('id')

    assert_equal '/v1/messages', @adapter.calls[0][:uri].path
    assert_equal 'cursor=cursor&limit=20&status=sent', @adapter.calls[0][:uri].query
    assert_equal '/v1/messages/a%2Fb', @adapter.calls[1][:uri].path
    assert_equal '/v1/messages/id/events', @adapter.calls[2][:uri].path
    assert_equal '/v1/messages/id/raw', @adapter.calls[6][:uri].path
    assert_equal 'message/rfc822', @adapter.calls[6][:request]['Accept']
    assert_raises(ViaPost::ValidationError) { @client.messages.retrieve('..') }
  end

  def test_inbound_message_routes_filters_and_binary_download
    @client.inbound_messages.list(
      cursor: 'cursor', limit: 25, domain_id: 'domain', search: 'subject', period: '7d', has_attachments: true
    )
    @client.inbound_messages.retrieve('a/b')
    @client.inbound_messages.raw('id')

    assert_equal '/v1/inbound-messages', @adapter.calls[0][:uri].path
    assert_equal(
      'cursor=cursor&limit=25&domain_id=domain&search=subject&period=7d&has_attachments=true',
      @adapter.calls[0][:uri].query
    )
    assert_equal '/v1/inbound-messages/a%2Fb', @adapter.calls[1][:uri].path
    assert_equal '/v1/inbound-messages/id/raw', @adapter.calls[2][:uri].path
    assert_equal 'message/rfc822', @adapter.calls[2][:request]['Accept']
    assert_raises(ViaPost::ValidationError) { @client.inbound_messages.list(period: '90d') }
  end

  def test_suppression_routes_validation_and_csv_transport
    @client.suppressions.list(
      cursor: 'next', limit: 25, search: 'example', reason: 'manual', state: 'active', origin: 'import'
    )
    @client.suppressions.create(email: 'blocked@example.com', reason: 'manual', note: 'requested')
    @client.suppressions.retrieve('id', history_cursor: 'older', history_limit: 25)
    @client.suppressions.release('id', expected_version: 2, acknowledge: true,
                                       justification: 'Verified safe removal')
    @client.suppressions.import_csv("email,reason,expires_at,note\na@example.com,manual,,\n")
    @client.suppressions.export_csv(state: 'all')

    assert_equal '/v1/suppressions', @adapter.calls[0][:uri].path
    assert_equal 'next', URI.decode_www_form(@adapter.calls[0][:uri].query).to_h.fetch('cursor')
    assert_equal '/v1/suppressions/id/release', @adapter.calls[3][:uri].path
    assert_equal 'text/csv', @adapter.calls[4][:request]['Content-Type']
    assert_equal 'text/csv', @adapter.calls[5][:request]['Accept']
    assert_raises(ViaPost::ValidationError) { @client.suppressions.list(limit: 51) }
    assert_raises(ViaPost::ValidationError) do
      @client.suppressions.create(email: 'blocked@example.com', reason: 'complaint')
    end
    assert_raises(ViaPost::ValidationError) do
      @client.suppressions.release('id', expected_version: 1, acknowledge: false,
                                         justification: 'Verified safe removal')
    end
    assert_raises(ViaPost::ValidationError) { @client.suppressions.import_csv('x' * ((2 * 1024 * 1024) + 1)) }
  end

  def test_domain_routes
    @client.domains.list
    @client.domains.create(name: 'example.com')
    @client.domains.retrieve('id')
    @client.domains.delete('id')
    @client.domains.rotate_dkim('id')
    @client.domains.dns('id')
    @client.domains.verify('id')

    assert_equal(%w[GET POST GET DELETE POST GET POST], @adapter.calls.map { |call| call[:request].method })
    assert_equal '/v1/domains/id/dkim/rotate', @adapter.calls[4][:uri].path
  end

  def test_template_routes_and_constraints
    @client.templates.list(cursor: 'now', limit: 5, search: 'welcome')
    @client.templates.create(name: 'Welcome')
    @client.templates.update_draft('id', content_json: {}, variables: [], expected_version_id: 'v',
                                         expected_updated_at: 't')
    @client.templates.preview('id', variables: { name: 'Ada' })
    @client.templates.publish('id')
    @client.templates.revert('id', 'version')

    assert_equal '/v1/templates/id/draft', @adapter.calls[2][:uri].path
    assert_raises(ViaPost::ValidationError) { @client.templates.create(name: '') }
    assert_raises(ViaPost::ValidationError) do
      @client.templates.update_draft('id', content_json: {}, variables: [], expected_version_id: 'v')
    end
  end

  def test_template_draft_distinguishes_omitted_and_explicit_null_subject
    @client.templates.update_draft('id', content_json: {}, variables: [])
    @client.templates.update_draft('id', content_json: {}, variables: [], subject: nil)

    omitted = JSON.parse(@adapter.calls[-2][:request].body)
    explicit_null = JSON.parse(@adapter.calls[-1][:request].body)
    refute omitted.key?('subject')
    assert explicit_null.key?('subject')
    assert_nil explicit_null['subject']
  end

  def test_webhook_routes_and_url_validation
    @client.webhooks.list
    Addrinfo.stub(:getaddrinfo, [Addrinfo.ip('93.184.216.34')]) do
      @client.webhooks.create(url: 'https://example.com/events', event_types: ['delivered'])
    end
    @client.webhooks.delete('id')

    assert_equal '/v1/webhooks', @adapter.calls[1][:uri].path
    assert_raises(ViaPost::ValidationError) do
      @client.webhooks.create(url: 'file:///etc/passwd', event_types: ['delivered'])
    end
    assert_raises(ViaPost::ValidationError) do
      @client.webhooks.create(url: 'https://example.com', event_types: [])
    end
  end

  def test_webhook_url_must_be_public_https_without_ambiguous_authority
    INVALID_WEBHOOK_URLS.each do |url|
      assert_raises(ViaPost::ValidationError, url) do
        @client.webhooks.create(url: url, event_types: ['delivered'])
      end
    end

    Addrinfo.stub(:getaddrinfo, [Addrinfo.ip('192.168.1.10')]) do
      assert_raises(ViaPost::ValidationError) do
        @client.webhooks.create(url: 'https://internal.example/events', event_types: ['delivered'])
      end
    end
    Addrinfo.stub(:getaddrinfo, [Addrinfo.ip('93.184.216.34')]) do
      @client.webhooks.create(url: 'https://public.example/events', event_types: ['delivered'])
    end
  end

  def test_webhook_operational_routes_and_idempotency
    @client.webhooks.update('id', expected_version: 2, enabled: true, max_attempts: 5)
    @client.webhooks.deliveries('id', cursor: 'next', limit: 25, status: 'failed', event_type: 'delivered')
    @client.webhooks.delivery('id', 'delivery')
    @client.webhooks.replay('id', 'delivery', idempotency_key: 'replay-1')
    @client.webhooks.rotate_secret('id', idempotency_key: 'rotate-1')
    @client.webhooks.test('id', idempotency_key: 'test-1')

    assert_equal '/v1/webhooks/id', @adapter.calls[0][:uri].path
    assert_equal '/v1/webhooks/id/deliveries', @adapter.calls[1][:uri].path
    assert_equal '/v1/webhooks/id/deliveries/delivery/replay', @adapter.calls[3][:uri].path
    assert_equal 'replay-1', @adapter.calls[3][:request]['Idempotency-Key']
    assert_equal '/v1/webhooks/id/secret/rotate', @adapter.calls[4][:uri].path
    assert_equal '/v1/webhooks/id/test', @adapter.calls[5][:uri].path
    assert_raises(ViaPost::ValidationError) { @client.webhooks.update('id', expected_version: 1) }
    assert_raises(ViaPost::ValidationError) do
      @client.webhooks.replay('id', 'delivery', idempotency_key: "unsafe\r\n")
    end
  end

  def test_automation_routes_and_run_pagination
    @client.automations.list(status: 'enabled', search: 'onboarding')
    @client.automations.create(name: 'Onboarding')
    @client.automations.rename('id', name: 'Welcome')
    @client.automations.update_draft('id', graph: { nodes: [] })
    @client.automations.runs('id', cursor: 'next', limit: 100, status: 'running')
    @client.automations.run('id', 'run')
    @client.automations.cancel_run('id', 'run')

    assert_equal '/v1/automations/id/runs', @adapter.calls[4][:uri].path
    assert_equal 'cursor=next&limit=100&status=running', @adapter.calls[4][:uri].query
    assert_raises(ViaPost::ValidationError) { @client.automations.runs('id', limit: 201) }
  end

  def test_usage_route
    @client.usage.retrieve

    assert_equal '/v1/usage', @adapter.calls.last[:uri].path
  end
end
