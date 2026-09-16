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
gem "viapost", github: "ViaPost-io/viapost-ruby", tag: "v0.1.0"
```

Depois execute `bundle install`. Releases também disponibilizam o arquivo `.gem` e seu checksum em
[GitHub Releases](https://github.com/ViaPost-io/viapost-ruby/releases). A publicação no RubyGems é
opcional e nunca acontece automaticamente.

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

client.domains.create(name: "example.com")
client.domains.verify("domain-id")
client.domains.dns("domain-id")

client.templates.create(name: "Boas-vindas")
client.templates.preview("template-id", variables: { name: "Ada" })

client.webhooks.create(
  url: "https://example.com/viapost/events",
  event_types: ["delivered", "bounced"]
)

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
gem "viapost", github: "ViaPost-io/viapost-ruby", tag: "v0.1.0"
```

Run `bundle install`, then initialize `ViaPost::Client` with `ENV.fetch("VIAPOST_API_KEY")`. Use
`client.send_email`, `messages`, `domains`, `templates`, `webhooks`, `automations`, and `usage`.
JSON responses are returned as symbol-keyed Ruby hashes. Only GET/HEAD requests are retried on 429
or 5xx responses; mutations are never retried.

## Contract and support

This beta is generated against ViaPost OpenAPI 3.1 contract SHA
`cb61b81b3276679426504eae4161e610eb5520aca2cd71cd267ed62628c518e4` from source commit
`891adebbe79a26178fb780ec986172c890a5e261`.

- [API documentation](https://docs.viapost.io)
- [Security policy](SECURITY.md)
- [Issues](https://github.com/ViaPost-io/viapost-ruby/issues)
