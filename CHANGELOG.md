# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- Keep JSON and error responses bounded at 8 MiB while allowing RFC 5322 and CSV downloads to use
  an independently configurable 40 MiB limit with a defensive 128 MiB ceiling.
- Prevent extra headers from replacing authorization, cookies, host, user-agent, compression,
  content negotiation, or hop-by-hop transport headers.
- Reject webhook destinations that are not public HTTPS URLs, including unsafe resolved addresses.
- Harden contract downloads with HTTPS-only same-origin redirects and bounded response bodies.
- Bind release and RubyGems publication to the attested source commit and embed that revision in
  package metadata.

## [0.2.0] - 2026-09-16

### Added

- Authenticated inbound message browsing and bounded RFC 5322 downloads.
- Suppression management, atomic CSV import, and bounded CSV export.
- Webhook updates, delivery inspection, replay, test delivery, and secret rotation.

### Changed

- Synchronized the vendored OpenAPI snapshot and public semantic drift monitor.
- Added explicit binary response and raw request-body transport modes.
- Redact newly rotated webhook secrets from inspection and serialization.

## [0.1.0] - 2026-09-11

### Added

- Initial beta SDK for Ruby 3.1+.
- Resources for send, messages, domains, templates, webhooks, automations, and usage.
- Bounded standard-library HTTP transport with typed errors and safe read retries.
- Vendored ViaPost OpenAPI contract and drift verification.

[Unreleased]: https://github.com/ViaPost-io/viapost-ruby/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ViaPost-io/viapost-ruby/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ViaPost-io/viapost-ruby/releases/tag/v0.1.0
