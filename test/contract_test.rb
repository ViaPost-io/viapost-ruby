# frozen_string_literal: true

require 'digest'
require 'json'
require 'yaml'
require_relative 'test_helper'

class ContractTest < Minitest::Test
  CONTRACT = File.expand_path('../openapi/public.yaml', __dir__)

  def test_vendored_contract_sha
    expected = '96f2fa883334ff15400f51f43bee917e690030e8f3e31b1d8dcdcca2782ab77b'

    assert_equal expected, Digest::SHA256.file(CONTRACT).hexdigest
  end

  def test_vendored_contract_contains_beta_routes
    contract = File.read(CONTRACT)

    %w[/v1/send /v1/messages /v1/inbound-messages /v1/suppressions /v1/domains /v1/templates
       /v1/webhooks /v1/automations /v1/usage].each do |route|
      assert_includes contract, "  #{route}:"
    end
  end

  def test_vendored_contract_contains_tracking_domain_lifecycle
    paths = contract_document.fetch('paths')

    expected_methods = {
      '/v1/domains/{domain_id}/tracking-domains' => %w[get post],
      '/v1/domains/{domain_id}/tracking-domains/{tracking_domain_id}' => %w[get],
      '/v1/domains/{domain_id}/tracking-domains/{tracking_domain_id}/verify' => %w[post],
      '/v1/domains/{domain_id}/tracking-domains/{tracking_domain_id}/activate' => %w[post],
      '/v1/domains/{domain_id}/tracking-domains/{tracking_domain_id}/revoke' => %w[post],
      '/v1/domains/{domain_id}/tracking-domains/{tracking_domain_id}/proof/rotate' => %w[post]
    }

    expected_methods.each do |path, methods|
      operation = paths.fetch(path)
      methods.each { |method| assert operation.key?(method), "missing #{method.upcase} #{path}" }
    end
  end

  def test_metrics_contract_requires_deliverability_section
    schema = contract_document.dig('components', 'schemas', 'MetricsResponse')

    assert_includes schema.fetch('required'), 'deliverability'
    assert_equal(
      '#/components/schemas/DeliverabilityMetrics',
      schema.dig('properties', 'deliverability', '$ref')
    )
    assert_equal(
      'private, no-store',
      contract_document.dig(
        'paths', '/v1/messages/metrics', 'get', 'responses', '200', 'headers',
        'Cache-Control', 'schema', 'const'
      )
    )
  end

  def test_public_status_tracking_verification_timestamp_is_conditional
    schema = contract_document.dig('components', 'schemas', 'PublicStatusComponent')

    refute_includes schema.fetch('required'), 'verified_at'
    assert_equal 'date-time', schema.dig('properties', 'verified_at', 'format')
    assert_equal 'Z$', schema.dig('properties', 'verified_at', 'pattern')
    assert_equal 'tracking', schema.dig('allOf', 0, 'if', 'properties', 'id', 'const')
    assert_equal 'unknown', schema.dig('allOf', 1, 'if', 'properties', 'status', 'const')
  end

  def test_message_timeline_contract_exposes_inbound_opt_in
    operation = contract_document.dig('paths', '/v1/messages/events', 'get')
    include_parameter = operation.fetch('parameters').find { |parameter| parameter['name'] == 'include' }

    assert_equal ['inbound'], include_parameter.dig('schema', 'enum')
    assert_equal 'inbound:read', operation.fetch('x-viapost-additional-scope-when-include-inbound')
    response_variants = operation.dig('responses', '200', 'content', 'application/json', 'schema', 'anyOf')
    assert_equal(
      ['#/components/schemas/MessageTimelinePage', '#/components/schemas/MessageTimelineOptInPage'],
      response_variants.map { |item| item.fetch('$ref') }
    )
  end

  def test_custom_event_send_contract_supports_idempotency_and_exactly_one_contact_identifier
    operation = contract_document.dig('paths', '/v1/events/send', 'post')
    idempotency = operation.fetch('parameters').find { |parameter| parameter['name'] == 'Idempotency-Key' }
    schema = contract_document.dig('components', 'schemas', 'SendCustomEventRequest')

    assert_equal 'header', idempotency.fetch('in')
    assert_equal false, idempotency.fetch('required')
    assert_equal ['event'], schema.fetch('required')
    assert_equal 2, schema.fetch('anyOf').length
    actual_identifiers = schema.fetch('anyOf').map { |variant| variant.fetch('required') }

    assert_equal [%w[contact_id], %w[email]], actual_identifiers
    assert_custom_event_identifier_variants(schema.fetch('anyOf'))
    assert schema.fetch('properties').key?('payload')
    refute schema.fetch('properties').key?('properties')
    assert_equal 'object', schema.dig('properties', 'payload', 'type')
    assert_equal true, schema.dig('properties', 'payload', 'additionalProperties')
    assert_equal 120, schema.dig('properties', 'event', 'maxLength')
    assert_equal '^[A-Za-z][A-Za-z0-9_-]*(\\.[A-Za-z0-9_-]+)*$', schema.dig('properties', 'event', 'pattern')
  end

  def test_saas_onboarding_recipe_is_session_only_and_not_exposed_by_api_key_client
    operation = contract_document.dig('paths', '/v1/automations/{id}/recipes/saas-onboarding', 'patch')

    assert_equal [{ 'sessionCookie' => [] }], operation.fetch('security')
    assert_equal 'automations:write', operation.fetch('x-viapost-scope')
    assert_equal '#/components/parameters/RequiredCsrfHeader', operation.fetch('parameters')[1].fetch('$ref')
    assert_equal 'X-ViaPost-Expected-Tenant-ID', operation.fetch('parameters')[2].fetch('name')
    assert_equal true, operation.fetch('parameters')[2].fetch('required')
    assert_equal %w[event_id template_id sender_domain_id],
                 contract_document.dig('components', 'schemas', 'MaterializeSaasOnboardingRecipeRequest', 'required')
    assert_equal true, contract_document.dig('components', 'parameters', 'RequiredCsrfHeader', 'required')
    refute_includes File.read(File.expand_path('../lib/viapost/resources/automations.rb', __dir__)),
                    '/recipes/saas-onboarding'
  end

  def test_contract_source_metadata_is_complete_and_matches_snapshot
    metadata = JSON.parse(File.read(File.expand_path('../docs/openapi-source.json', __dir__)))

    assert_equal 'https://docs.viapost.io/openapi/public.yaml', metadata.fetch('url')
    assert_equal Digest::SHA256.file(CONTRACT).hexdigest, metadata.fetch('sha256')
    assert_equal 'b26db96bca4586b42bd6e2d7741e29bb12f411b1', metadata.fetch('source_commit')
  end

  private

  def assert_custom_event_identifier_variants(variants)
    properties_by_identifier = variants.to_h do |variant|
      [variant.fetch('required').fetch(0), variant.fetch('properties')]
    end
    contact_variant = properties_by_identifier.fetch('contact_id')
    email_variant = properties_by_identifier.fetch('email')
    trimmed_email_pattern = '^\\s+[^@\\s]+@[^@\\s]+\\.[^@\\s]+\\s*$|^[^@\\s]+@[^@\\s]+\\.[^@\\s]+\\s+$'

    assert_equal '#/components/schemas/UUID', contact_variant.dig('contact_id', '$ref')
    assert_equal [{ 'type' => 'null' }, { 'type' => 'string', 'const' => '' }], contact_variant.dig('email', 'anyOf')
    assert_equal 'null', email_variant.dig('contact_id', 'type')
    assert_equal(
      [{ 'type' => 'string', 'format' => 'email' }, { 'type' => 'string', 'pattern' => trimmed_email_pattern }],
      email_variant.dig('email', 'anyOf')
    )
  end

  def contract_document
    @contract_document ||= YAML.safe_load_file(CONTRACT, aliases: false)
  end
end
