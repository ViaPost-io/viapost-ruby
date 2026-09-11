# frozen_string_literal: true

require_relative 'test_helper'

class ClientTest < Minitest::Test
  def test_builds_authenticated_json_request_and_symbolizes_response
    adapter = FakeAdapter.new(response(body: '{"id":"msg_1","nested":{"ok":true}}'))

    result = client(adapter: adapter).request(:get, '/v1/messages/msg_1')
    call = adapter.calls.fetch(0)

    assert_equal 'Bearer vp_test_secret', call[:request]['Authorization']
    assert_equal 'application/json', call[:request]['Accept']
    assert_equal 'identity', call[:request]['Accept-Encoding']
    assert_match(%r{viapost-ruby/0\.1\.0}, call[:request]['User-Agent'])
    assert_equal({ id: 'msg_1', nested: { ok: true } }, result)
  end

  def test_returns_nil_for_no_content
    adapter = FakeAdapter.new(response(status: 204, body: ''))

    assert_nil client(adapter: adapter).request(:delete, '/v1/domains/id')
  end

  def test_maps_api_error_and_keeps_secret_out_of_error
    body = '{"error":{"code":"quota_exceeded","message":"Limit reached: vp_test_secret","request_id":"req_1"}}'
    adapter = FakeAdapter.new(response(status: 429, body: body, headers: { 'retry-after' => '9' }))

    error = assert_raises(ViaPost::RateLimitError) do
      client(adapter: adapter, max_retries: 0).request(:get, '/v1/messages')
    end

    assert_equal 429, error.status
    assert_equal 'quota_exceeded', error.code
    assert_equal 'req_1', error.request_id
    assert_equal 9.0, error.retry_after
    refute_includes error.inspect, 'vp_test_secret'
    refute_includes error.message, 'vp_test_secret'
  end

  def test_retries_get_on_server_error_but_never_mutations
    get_adapter = FakeAdapter.new(response(status: 503), response(body: '{"ok":true}'))
    post_adapter = FakeAdapter.new(response(status: 503), response(body: '{"ok":true}'))

    assert_equal({ ok: true }, client(adapter: get_adapter).request(:get, '/v1/messages'))
    assert_equal 2, get_adapter.calls.length
    assert_raises(ViaPost::ServerError) do
      client(adapter: post_adapter).request(:post, '/v1/send', body: { from: 'a', to: ['b'] })
    end
    assert_equal 1, post_adapter.calls.length
  end

  def test_clamps_negative_retry_after_before_sleeping
    delays = []
    adapter = FakeAdapter.new(response(status: 429, headers: { 'retry-after' => '-10' }), response(body: '{}'))
    configured = ViaPost::Client.new(
      api_key: 'vp_test_secret', adapter: adapter, sleeper: ->(delay) { delays << delay }, max_retries: 1
    )

    configured.request(:get, '/v1/messages')

    assert_equal [0], delays
  end

  def test_rejects_invalid_success_json
    adapter = FakeAdapter.new(response(body: '<html>not json</html>'))

    assert_raises(ViaPost::DecodeError) { client(adapter: adapter).request(:get, '/v1/messages') }
  end

  def test_non_json_api_error_preserves_http_diagnostics
    adapter = FakeAdapter.new(response(
                                status: 500,
                                body: '<html>proxy failure</html>',
                                headers: { 'x-request-id' => 'req_proxy' }
                              ))

    error = assert_raises(ViaPost::ServerError) do
      client(adapter: adapter, max_retries: 0).request(:get, '/v1/messages')
    end

    assert_equal 500, error.status
    assert_equal 'req_proxy', error.request_id
    refute_includes error.message, '<html>'
  end

  def test_timeout_covers_retries_and_backoff_as_one_operation
    adapter = FakeAdapter.new(response(status: 503), response(body: '{"ok":true}'))
    configured = ViaPost::Client.new(
      api_key: 'vp_test_secret',
      adapter: adapter,
      sleeper: ->(_delay) { sleep 0.05 },
      timeout: 0.01,
      max_retries: 1
    )

    assert_raises(ViaPost::TimeoutError) { configured.request(:get, '/v1/messages') }
    assert_equal 1, adapter.calls.length
  end

  def test_does_not_follow_redirects_or_allow_cookie_and_auth_overrides
    adapter = FakeAdapter.new(response(status: 302, headers: { 'location' => 'https://evil.example' }))

    assert_raises(ViaPost::APIError) do
      client(adapter: adapter, max_retries: 0).request(
        :get,
        '/v1/messages',
        headers: { 'Authorization' => 'Bearer attacker', 'Cookie' => 'session=bad' }
      )
    end

    request = adapter.calls.first[:request]
    assert_equal 'Bearer vp_test_secret', request['Authorization']
    assert_nil request['Cookie']
    assert_equal 1, adapter.calls.length
  end

  def test_encodes_query_without_mutating_input
    filters = { cursor: '2026-01-01T00:00:00Z', limit: 25, status: nil }
    adapter = FakeAdapter.new

    client(adapter: adapter).request(:get, '/v1/messages', params: filters)

    assert_equal({ cursor: '2026-01-01T00:00:00Z', limit: 25, status: nil }, filters)
    assert_equal 'cursor=2026-01-01T00%3A00%3A00Z&limit=25', adapter.calls[0][:uri].query
  end
end
