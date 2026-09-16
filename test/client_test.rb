# frozen_string_literal: true

require_relative 'test_helper'

class ClientTest < Minitest::Test
  MALICIOUS_HEADERS = {
    'Authorization' => 'Bearer attacker', 'Cookie' => 'session=bad', 'Host' => 'evil.example',
    'User-Agent' => 'evil-agent', 'Accept' => 'text/evil', 'Accept-Encoding' => 'gzip',
    'Connection' => 'keep-alive, X-Evil', 'Keep-Alive' => 'timeout=999',
    'Proxy-Authorization' => 'Basic bad', 'TE' => 'trailers', 'Trailer' => 'X-Evil',
    'Transfer-Encoding' => 'chunked', 'Upgrade' => 'websocket', 'X-Evil' => 'yes'
  }.freeze

  def test_builds_authenticated_json_request_and_symbolizes_response
    adapter = FakeAdapter.new(response(body: '{"id":"msg_1","nested":{"ok":true}}'))

    result = client(adapter: adapter).request(:get, '/v1/messages/msg_1')
    call = adapter.calls.fetch(0)

    assert_equal 'Bearer vp_test_secret', call[:request]['Authorization']
    assert_equal 'application/json', call[:request]['Accept']
    assert_equal 'identity', call[:request]['Accept-Encoding']
    assert_match(%r{viapost-ruby/0\.2\.0}, call[:request]['User-Agent'])
    assert_equal({ id: 'msg_1', nested: { ok: true } }, result)
  end

  def test_returns_nil_for_no_content
    adapter = FakeAdapter.new(response(status: 204, body: ''))

    assert_nil client(adapter: adapter).request(:delete, '/v1/domains/id')
  end

  def test_returns_binary_success_without_json_decoding
    eml = "From: sender@example.com\r\n\r\nbody".b
    adapter = FakeAdapter.new(response(body: eml, headers: { 'content-type' => 'message/rfc822' }))

    result = client(adapter: adapter).request(
      :get,
      '/v1/messages/id/raw',
      accept: 'message/rfc822',
      response_format: :binary
    )

    assert_equal eml, result
    assert_equal Encoding::BINARY, result.encoding
    assert_equal 'message/rfc822', adapter.calls.first[:request]['Accept']
    assert_equal 40 * 1024 * 1024, adapter.calls.first[:max_response_bytes]
    assert_equal 8 * 1024 * 1024, adapter.calls.first[:max_error_response_bytes]
  end

  def test_sends_raw_csv_body_with_explicit_content_type
    adapter = FakeAdapter.new(response(body: '{"created":1}'))

    client(adapter: adapter).request(
      :post,
      '/v1/suppressions/import',
      body: "email,reason\na@example.com,manual\n",
      content_type: 'text/csv'
    )

    request = adapter.calls.first[:request]
    assert_equal 'text/csv', request['Content-Type']
    assert_equal "email,reason\na@example.com,manual\n", request.body
  end

  def test_rejects_unknown_response_format_before_network
    adapter = FakeAdapter.new

    assert_raises(ArgumentError) do
      client(adapter: adapter).request(:get, '/v1/messages', response_format: :xml)
    end
    assert_empty adapter.calls
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

  def test_api_error_redacts_named_secrets_from_message_and_details
    secret = 'whsec_never_log_this'
    body = JSON.generate(error: { code: 'invalid', message: "failed #{secret}", secret: secret })
    adapter = FakeAdapter.new(response(status: 400, body: body,
                                       headers: { 'x-request-id' => "request-#{secret}" }))

    error = assert_raises(ViaPost::BadRequestError) { client(adapter: adapter).usage.retrieve }

    [error.message, error.inspect, error.request_id, error.details.inspect].each do |representation|
      refute_includes representation, secret
    end
    assert_equal '[REDACTED]', error.details[:secret]
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
        headers: MALICIOUS_HEADERS
      )
    end

    request = adapter.calls.first[:request]
    assert_equal 'Bearer vp_test_secret', request['Authorization']
    assert_nil request['Cookie']
    assert_nil request['Host']
    assert_match(%r{viapost-ruby/0\.2\.0}, request['User-Agent'])
    assert_equal 'application/json', request['Accept']
    assert_equal 'identity', request['Accept-Encoding']
    %w[Connection Keep-Alive Proxy-Authorization TE Trailer Transfer-Encoding Upgrade X-Evil].each do |header|
      assert_nil request[header]
    end
    assert_equal 1, adapter.calls.length
  end

  def test_json_and_binary_successes_use_independent_configurable_limits
    adapter = FakeAdapter.new(response(body: '{}'), response(body: 'csv'))
    configured = client(adapter: adapter, max_response_bytes: 1024, max_raw_response_bytes: 4096)

    configured.request(:get, '/v1/messages')
    configured.request(:get, '/v1/suppressions/export', accept: 'text/csv', response_format: :binary)

    success_limits = adapter.calls.map { |call| call[:max_response_bytes] }
    error_limits = adapter.calls.map { |call| call[:max_error_response_bytes] }
    assert_equal [1024, 4096], success_limits
    assert_equal [1024, 1024], error_limits
  end

  def test_encodes_query_without_mutating_input
    filters = { cursor: '2026-01-01T00:00:00Z', limit: 25, status: nil }
    adapter = FakeAdapter.new

    client(adapter: adapter).request(:get, '/v1/messages', params: filters)

    assert_equal({ cursor: '2026-01-01T00:00:00Z', limit: 25, status: nil }, filters)
    assert_equal 'cursor=2026-01-01T00%3A00%3A00Z&limit=25', adapter.calls[0][:uri].query
  end
end
