# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../scripts/check_contract'

class ContractDownloaderTest < Minitest::Test
  FakeResponse = Struct.new(:code, :headers, :chunks) do
    def [](name)
      headers[name] || headers[name.downcase]
    end

    def read_body(&block)
      chunks.each(&block)
    end
  end

  class FakeHttp
    attr_accessor :use_ssl, :verify_mode, :open_timeout, :read_timeout

    def initialize(responses)
      @responses = responses
    end

    def start
      yield self
    end

    def request(_request)
      yield @responses.shift
    end
  end

  def test_download_is_limited_and_allows_only_same_origin_https_redirects
    responses = [
      FakeResponse.new('302', { 'location' => '/canonical.yaml' }, []),
      FakeResponse.new('200', {}, %w[1234 5678])
    ]
    factory = ->(_uri) { FakeHttp.new(responses) }

    assert_equal '12345678', ContractCheck.fetch(
      URI('https://docs.viapost.io/openapi/public.yaml'), max_bytes: 8, http_factory: factory
    )

    cross_origin = [FakeResponse.new('302', { 'location' => 'https://evil.example/contract' }, [])]
    error = assert_raises(ContractCheck::DownloadError) do
      ContractCheck.fetch(
        URI('https://docs.viapost.io/openapi/public.yaml'),
        http_factory: ->(_uri) { FakeHttp.new(cross_origin) }
      )
    end
    assert_match(/same origin/, error.message)

    assert_raises(ContractCheck::DownloadError) do
      ContractCheck.fetch(URI('http://docs.viapost.io/openapi/public.yaml'), http_factory: factory)
    end
  end

  def test_download_rejects_oversized_body_and_redirect_loops
    oversized = [FakeResponse.new('200', {}, %w[1234 56789])]
    assert_raises(ContractCheck::DownloadError) do
      ContractCheck.fetch(
        URI('https://docs.viapost.io/openapi/public.yaml'),
        max_bytes: 8,
        http_factory: ->(_uri) { FakeHttp.new(oversized) }
      )
    end

    redirects = Array.new(4) { FakeResponse.new('302', { 'location' => '/again' }, []) }
    assert_raises(ContractCheck::DownloadError) do
      ContractCheck.fetch(
        URI('https://docs.viapost.io/openapi/public.yaml'),
        redirect_limit: 3,
        http_factory: ->(_uri) { FakeHttp.new(redirects) }
      )
    end
  end
end
