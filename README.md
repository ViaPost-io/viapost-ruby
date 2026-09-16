# ViaPost Ruby SDK

Official, dependency-light Ruby SDK for the [ViaPost](https://viapost.io) API. Runtime HTTP and JSON
handling use Ruby's standard library. This project is currently beta.

## Português

### Requisitos

- Ruby 3.1+
- uma API key ViaPost com os scopes exigidos pelos recursos usados

### Instalação pelo GitHub

Adicione ao `Gemfile` usando uma tag imutável:

```ruby
gem "viapost", github: "ViaPost-io/viapost-ruby", tag: "v0.2.0"
```

Depois execute `bundle install`. Releases também disponibilizam o arquivo `.gem` e seu checksum em
[GitHub Releases](https://github.com/ViaPost-io/viapost-ruby/releases). A publicação no RubyGems é
opcional e nunca acontece automaticamente. Cada release inclui `SOURCE_SHA`, valida a atestação do
pacote contra esse commit e grava o mesmo SHA em `source_code_uri` nos metadados da gem.

### Primeiro envio

```ruby
require "viapost"

client = ViaPost::Client.new(api_key: ENV.fetch("VIAPOST_API_KEY"))

result = client.send_email.create(
  from: "hello@example.com",
  to: ["dev@example.com"],
  subject: "Olá do ViaPost",
  html: "<p>Olá!</p>",
  idempotency_key: "order-42-welcome"
)

puts result[:accepted]
```

### Recursos

Todos os retornos JSON são hashes Ruby com chaves simbólicas.

```ruby
client.messages.list(limit: 25, status: "delivered")
client.messages.retrieve("message-id")
client.messages.events("message-id")
raw_message = client.messages.raw("message-id")

client.inbound_messages.list(period: "7d", has_attachments: true)
client.inbound_messages.retrieve("inbound-message-id")
raw_inbound = client.inbound_messages.raw("inbound-message-id")

client.suppressions.list(state: "active", limit: 25)
client.suppressions.create(email: "blocked@example.com", reason: "manual")
client.suppressions.export_csv(state: "all")

client.domains.create(name: "example.com")
client.domains.verify("domain-id")
client.domains.dns("domain-id")

client.templates.create(name: "Boas-vindas")
client.templates.preview("template-id", variables: { name: "Ada" })

client.webhooks.create(
  url: "https://example.com/viapost/events",
  event_types: ["delivered", "hard_bounce"]
)
client.webhooks.deliveries("webhook-id", status: "failed")
client.webhooks.delivery("webhook-id", "delivery-id") # payload seguro e tentativas, sem bodies/secrets
client.webhooks.replay("webhook-id", "delivery-id", idempotency_key: "replay-42")
client.webhooks.rotate_secret("webhook-id", idempotency_key: "rotation-42")

client.automations.list(status: "enabled")
client.automations.runs("automation-id", limit: 50)
client.usage.retrieve
```

Para desenvolvimento local, HTTP é aceito somente em loopback:

```ruby
ViaPost::Client.new(
  api_key: ENV.fetch("VIAPOST_API_KEY"),
  base_url: "http://127.0.0.1:15080"
)
```

### Erros e retries

Erros da API derivam de `ViaPost::APIError` e expõem `status`, `code`, `request_id` e
`retry_after`. O `timeout` padrão de 60 segundos cobre a operação inteira, incluindo tentativas e
backoff. Falhas de rede, timeout, JSON inválido e resposta acima de 8 MiB possuem classes
específicas. Apenas GET/HEAD são repetidos em `429` ou `5xx`; mutações nunca são repetidas pelo SDK.

Respostas JSON e corpos de erro permanecem limitados a 8 MiB. Downloads RFC 5322 e exportações
CSV usam um limite separado de 40 MiB, configurável por `max_raw_response_bytes` até o teto
defensivo de 128 MiB. Cabeçalhos adicionais não podem substituir autenticação, host, user-agent,
compressão, `Accept` ou cabeçalhos hop-by-hop. O `Accept` deve ser definido pela operação do SDK.

Destinos de webhook precisam usar HTTPS público. URLs com credenciais, fragmentos, localhost ou
endereços privados, reservados, loopback, link-local e não especificados são rejeitadas localmente;
o servidor ViaPost também revalida o destino antes de usá-lo.

```ruby
begin
  client.usage.retrieve
rescue ViaPost::RateLimitError => error
  warn "Tente novamente em #{error.retry_after}s (request #{error.request_id})"
end
```

## English

### Requirements and installation

Ruby 3.1+ is required. Add the immutable GitHub tag to your `Gemfile`:

```ruby
gem "viapost", github: "ViaPost-io/viapost-ruby", tag: "v0.2.0"
```

Run `bundle install`, then initialize `ViaPost::Client` with `ENV.fetch("VIAPOST_API_KEY")`. Use
`client.send_email`, `messages`, `inbound_messages`, `suppressions`, `domains`, `templates`,
`webhooks`, `automations`, and `usage`.
JSON responses are returned as symbol-keyed Ruby hashes. Only GET/HEAD requests are retried on 429
or 5xx responses; mutations are never retried.

JSON and error bodies are capped at 8 MiB. RFC 5322 and CSV downloads have an independent 40 MiB
default, configurable up to a defensive 128 MiB ceiling. Extra headers cannot override protected
transport headers, and webhook destinations must be public HTTPS URLs.

Message detail content is the server-sanitized submitted/received preview and should still be
rendered as untrusted content. Raw RFC 5322 downloads are explicit binary operations. Webhook
delivery details contain only the contract's allowlisted, redacted payload summary and attempt
metadata; destination response bodies, endpoint URLs, and credentials are not returned.

## Contract and support

This beta is generated against ViaPost OpenAPI 3.1 contract SHA
`f1b1fc0f198a2b0b36f0e893515dad191d6bb7d139fcf1e942c036bfa2f5169b` from source commit
`891adebbe79a26178fb780ec986172c890a5e261`.

The anonymous public status subscription endpoints are intentionally not exposed through this
Bearer-authenticated client. Keeping them separate prevents an API key from being sent to
`status.viapost.io`; applications should call that public origin without ViaPost authorization.

- [API documentation](https://docs.viapost.io)
- [Security policy](SECURITY.md)
- [Issues](https://github.com/ViaPost-io/viapost-ruby/issues)
