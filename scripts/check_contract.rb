#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'net/http'
require 'uri'
require 'yaml'

EXPECTED_SHA = 'cb61b81b3276679426504eae4161e610eb5520aca2cd71cd267ed62628c518e4'
SOURCE_COMMIT = '891adebbe79a26178fb780ec986172c890a5e261'
CONTRACT_URL = URI('https://docs.viapost.io/openapi/public.yaml')
LOCAL_CONTRACT = File.expand_path('../openapi/public.yaml', __dir__)
MAX_BYTES = 8 * 1024 * 1024

def verify_sha(content, label)
  actual = Digest::SHA256.hexdigest(content)
  abort "#{label} SHA mismatch: expected #{EXPECTED_SHA}, got #{actual}" unless actual == EXPECTED_SHA
end

local = File.binread(LOCAL_CONTRACT)
verify_sha(local, 'Vendored contract')

if ARGV.include?('--remote')
  request = Net::HTTP::Get.new(CONTRACT_URL)
  request['Accept-Encoding'] = 'identity'
  request['User-Agent'] = 'viapost-ruby-contract-check/0.1'
  remote = Net::HTTP.start(CONTRACT_URL.host, CONTRACT_URL.port, use_ssl: true, open_timeout: 5,
                                                                 read_timeout: 15) do |http|
    body = String.new(encoding: Encoding::BINARY)
    http.request(request) do |response|
      abort "Published contract returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.read_body do |chunk|
        abort "Published contract exceeds #{MAX_BYTES} bytes" if body.bytesize + chunk.bytesize > MAX_BYTES

        body << chunk
      end
    end
    body
  end

  local_document = YAML.safe_load(local, aliases: false)
  remote_document = YAML.safe_load(remote, aliases: false)
  abort 'Published contract differs semantically from vendored OpenAPI' unless remote_document == local_document
end

puts "OpenAPI contract matches #{EXPECTED_SHA} (source #{SOURCE_COMMIT})."
