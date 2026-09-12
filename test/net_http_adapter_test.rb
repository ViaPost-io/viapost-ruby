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
      adapter.perform(uri: URI('https://example.com'), request: Net::HTTP::Get.new('/'), max_response_bytes: 7)
    end

    assert_match(/7 bytes/, error.message)
    assert_equal OpenSSL::SSL::VERIFY_PEER, http.verify_mode
  end

  def test_maps_timeout_without_request_secrets
    factory = lambda do |_uri|
      raise Net::OpenTimeout, 'connection timed out for vp_live_never_echo'
    end
    adapter = ViaPost::NetHttpAdapter.new(open_timeout: 1, read_timeout: 1, write_timeout: 1, http_factory: factory)

    error = assert_raises(ViaPost::TimeoutError) do
      adapter.perform(uri: URI('https://example.com'), request: Net::HTTP::Get.new('/'), max_response_bytes: 8)
    end

    assert_equal 'ViaPost request timed out', error.message
  end
end
