# frozen_string_literal: true

require 'minitest/autorun'
require 'viapost'

class FakeAdapter
  attr_reader :calls

  def initialize(*responses)
    @responses = responses.flatten
    @calls = []
  end

  def perform(uri:, request:, max_response_bytes:)
    @calls << { uri: uri, request: request, max_response_bytes: max_response_bytes }
    response = @responses.shift
    raise response if response.is_a?(Exception)

    response || ViaPost::TransportResponse.new(status: 200, headers: {}, body: '{}')
  end
end

module ResponseFactory
  def response(status: 200, body: '{}', headers: {})
    ViaPost::TransportResponse.new(status: status, headers: headers, body: body)
  end

  def client(adapter:, **options)
    ViaPost::Client.new(api_key: 'vp_test_secret', adapter: adapter, sleeper: ->(_delay) {}, **options)
  end
end

module Minitest
  class Test
    include ResponseFactory
  end
end
