# frozen_string_literal: true

require_relative 'lib/viapost/version'

Gem::Specification.new do |spec|
  source_sha = ENV.fetch('VIAPOST_SOURCE_SHA', nil)
  unless source_sha.nil? || source_sha.match?(/\A[0-9a-f]{40}\z/)
    raise 'VIAPOST_SOURCE_SHA must be a full lowercase commit SHA'
  end

  spec.name = 'viapost'
  spec.version = ViaPost::VERSION
  spec.authors = ['ViaPost']
  spec.email = ['support@viapost.io']
  spec.summary = 'Official Ruby SDK for the ViaPost email API'
  spec.description = 'Send email and manage outbound and inbound messages, suppressions, domains, ' \
                     'templates, webhooks, automations, and usage with ViaPost.'
  spec.homepage = 'https://github.com/ViaPost-io/viapost-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/ViaPost-io/viapost-ruby/issues',
    'changelog_uri' => 'https://github.com/ViaPost-io/viapost-ruby/blob/main/CHANGELOG.md',
    'documentation_uri' => 'https://docs.viapost.io',
    'homepage_uri' => spec.homepage,
    'source_code_uri' => source_sha ? "#{spec.homepage}/tree/#{source_sha}" : spec.homepage,
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir.glob(%w[lib/**/* openapi/**/* README.md LICENSE CHANGELOG.md SECURITY.md], File::FNM_DOTMATCH)
  spec.require_paths = ['lib']
end
