# Contributing

## Local development

Ruby 3.1 or newer is required.

```bash
bundle install
bundle exec rake test
bundle exec rubocop
bundle exec bundler-audit check --update
ruby scripts/check_contract.rb
gem build viapost.gemspec
```

New behavior must follow Red → Green → Refactor. Do not use real API keys in tests. Pull requests
must update tests and documentation together and keep the vendored OpenAPI contract synchronized.

## Contract updates

Replace `openapi/public.yaml` only with the public document from the ViaPost source repository,
then update the expected SHA in `scripts/check_contract.rb` in the same reviewed change.

