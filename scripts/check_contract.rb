#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'net/http'
require 'openssl'
require 'uri'
require 'yaml'

module ContractCheck
  EXPECTED_SHA = 'f1b1fc0f198a2b0b36f0e893515dad191d6bb7d139fcf1e942c036bfa2f5169b'
  SOURCE_COMMIT = '891adebbe79a26178fb780ec986172c890a5e261'
  CONTRACT_URL = URI(ENV.fetch('OPENAPI_SOURCE_URL', 'https://docs.viapost.io/openapi/public.yaml'))
  LOCAL_CONTRACT = File.expand_path('../openapi/public.yaml', __dir__)
  MAX_BYTES = 8 * 1024 * 1024
  MAX_REDIRECTS = 3

  class DownloadError < StandardError; end

  module_function

  def verify_sha(content, label)
    actual = Digest::SHA256.hexdigest(content)
    raise DownloadError, "#{label} SHA mismatch: expected #{EXPECTED_SHA}, got #{actual}" unless actual == EXPECTED_SHA
  end

  def fetch(uri, max_bytes: MAX_BYTES, redirect_limit: MAX_REDIRECTS, http_factory: method(:build_http),
            original_origin: nil)
    validate_download_uri!(uri)
    original_origin ||= origin(uri)
    raise DownloadError, 'contract redirect limit exceeded' if redirect_limit.negative?

    response, body = perform_request(uri, max_bytes, http_factory)
    status = response.code.to_i
    return body if status.between?(200, 299)

    raise DownloadError, "Published contract returned HTTP #{response.code}" unless status.between?(300, 399)

    redirected = redirect_uri(response, uri, original_origin)

    fetch(
      redirected,
      max_bytes: max_bytes,
      redirect_limit: redirect_limit - 1,
      http_factory: http_factory,
      original_origin: original_origin
    )
  rescue URI::InvalidURIError
    raise DownloadError, 'contract redirect Location is invalid'
  end

  def redirect_uri(response, current_uri, original_origin)
    location = response['location']
    raise DownloadError, 'contract redirect did not include Location' if location.nil? || location.empty?

    redirected = URI.join(current_uri, location)
    validate_download_uri!(redirected)
    return redirected if origin(redirected) == original_origin

    raise DownloadError, 'contract redirects must remain on the same origin'
  end

  def perform_request(uri, max_bytes, http_factory)
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Accept-Encoding'] = 'identity'
    request['User-Agent'] = 'viapost-ruby-contract-check/0.2'
    body = String.new(encoding: Encoding::BINARY)
    response = nil
    http = http_factory.call(uri)
    http.start do |session|
      session.request(request) do |raw_response|
        response = raw_response
        next unless raw_response.code.to_i.between?(200, 299)

        content_length = Integer(raw_response['content-length'], exception: false)
        if content_length && content_length > max_bytes
          raise DownloadError, "Published contract exceeds #{max_bytes} bytes"
        end

        raw_response.read_body do |chunk|
          if body.bytesize + chunk.bytesize > max_bytes
            raise DownloadError, "Published contract exceeds #{max_bytes} bytes"
          end

          body << chunk
        end
      end
    end
    [response, body]
  end

  def build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.open_timeout = 5
    http.read_timeout = 15
    http
  end

  def validate_download_uri!(uri)
    valid = uri.is_a?(URI::HTTPS) && uri.host && !uri.userinfo && !uri.fragment
    raise DownloadError, 'OPENAPI_SOURCE_URL and redirects must use an unambiguous HTTPS URL' unless valid
  end

  def origin(uri)
    [uri.scheme.downcase, uri.hostname.downcase, uri.port]
  end

  def run(remote: false)
    local = File.binread(LOCAL_CONTRACT)
    verify_sha(local, 'Vendored contract')

    if remote
      remote_content = fetch(CONTRACT_URL)
      local_document = YAML.safe_load(local, aliases: false)
      remote_document = YAML.safe_load(remote_content, aliases: false)
      unless remote_document == local_document
        raise DownloadError, 'Published contract differs semantically from vendored OpenAPI'
      end
    end

    puts "OpenAPI contract matches #{EXPECTED_SHA} (source #{SOURCE_COMMIT})."
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    ContractCheck.run(remote: ARGV.include?('--remote'))
  rescue ContractCheck::DownloadError => e
    abort e.message
  end
end
