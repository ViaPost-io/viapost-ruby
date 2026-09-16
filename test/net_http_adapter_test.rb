# frozen_string_literal: true

require_relative 'test_helper'

class NetHttpAdapterTest < Minitest::Test
  FakeBodyResponse = Struct.new(:code, :headers, :chunks) do
    def each_header(&block)
      headers.each(&block)
    end

    def read_body(&block)
      chunks.each(&block)
    end
  end

  FakeHttp = Struct.new(:response) do
    attr_accessor :use_ssl, :verify_mode, :open_timeout, :read_timeout, :write_timeout

    def request(_request)
      yield response
    end
  end

  def test_streams_and_limits_decoded_response
    http = FakeHttp.new(FakeBodyResponse.new('200', {}, %w[1234 5678]))
    adapter = ViaPost::NetHttpAdapter.new(
      open_timeout: 1, read_timeout: 1, write_timeout: 1, http_factory: ->(_uri) { http }
    )

    error = assert_raises(ViaPost::ResponseTooLargeError) do
      adapter.perform(
        uri: URI('https://example.com'),
        request: Net::HTTP::Get.new('/'),
        max_response_bytes: 7,
        max_error_response_bytes: 7
      )
    end

    assert_match(/7 bytes/, error.message)
    assert_equal OpenSSL::SSL::VERIFY_PEER, http.verify_mode
  end

  def test_uses_the_json_limit_for_errors_even_when_raw_successes_allow_more
    success_http = FakeHttp.new(FakeBodyResponse.new('200', {}, %w[1234 5678]))
    error_http = FakeHttp.new(FakeBodyResponse.new('500', {}, %w[1234 5678]))
    success_adapter = ViaPost::NetHttpAdapter.new(
      open_timeout: 1, read_timeout: 1, write_timeout: 1, http_factory: ->(_uri) { success_http }
    )
    error_adapter = ViaPost::NetHttpAdapter.new(
      open_timeout: 1, read_timeout: 1, write_timeout: 1, http_factory: ->(_uri) { error_http }
    )

    result = success_adapter.perform(
      uri: URI('https://example.com'),
      request: Net::HTTP::Get.new('/'),
      max_response_bytes: 9,
      max_error_response_bytes: 7
    )
    assert_equal '12345678', result.body
    assert_raises(ViaPost::ResponseTooLargeError) do
      error_adapter.perform(
        uri: URI('https://example.com'),
        request: Net::HTTP::Get.new('/'),
        max_response_bytes: 9,
        max_error_response_bytes: 7
      )
    end
  end

  def test_maps_timeout_without_request_secrets
    factory = lambda do |_uri|
      raise Net::OpenTimeout, 'connection timed out for vp_live_never_echo'
    end
    adapter = ViaPost::NetHttpAdapter.new(open_timeout: 1, read_timeout: 1, write_timeout: 1, http_factory: factory)

    error = assert_raises(ViaPost::TimeoutError) do
      adapter.perform(
        uri: URI('https://example.com'),
        request: Net::HTTP::Get.new('/'),
        max_response_bytes: 8,
        max_error_response_bytes: 8
      )
    end

    assert_equal 'ViaPost request timed out', error.message
  end
end
