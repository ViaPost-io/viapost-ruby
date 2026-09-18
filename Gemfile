# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development, :test do
  gem 'bundler-audit', '~> 0.9', require: false
  # Minitest 6 requires Ruby >= 3.2, while this SDK supports Ruby 3.1.
  gem 'minitest', '>= 5.25', '< 6.0'
  gem 'rake', '~> 13.2'
  gem 'rubocop', '~> 1.75', require: false
end
