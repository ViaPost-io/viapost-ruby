# frozen_string_literal: true

require_relative 'viapost/version'
require_relative 'viapost/errors'
require_relative 'viapost/api_error_factory'
require_relative 'viapost/configuration'
require_relative 'viapost/net_http_adapter'
require_relative 'viapost/sensitive_response'
require_relative 'viapost/resources/base'
require_relative 'viapost/resources/send'
require_relative 'viapost/resources/messages'
require_relative 'viapost/resources/inbound_messages'
require_relative 'viapost/resources/suppressions'
require_relative 'viapost/resources/domains'
require_relative 'viapost/resources/templates'
require_relative 'viapost/resources/webhooks'
require_relative 'viapost/resources/automations'
require_relative 'viapost/resources/usage'
require_relative 'viapost/client'

module ViaPost
  def self.contract_path
    File.expand_path('../openapi/public.yaml', __dir__)
  end
end
