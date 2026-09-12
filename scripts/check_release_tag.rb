#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/viapost/version'

tag = ARGV.fetch(0, '')
expected = "v#{ViaPost::VERSION}"
abort "Release tag must be exactly #{expected}; received #{tag.empty? ? '<empty>' : tag}" unless tag == expected

puts "Release tag #{tag} matches viapost #{ViaPost::VERSION}."
