# frozen_string_literal: true

require_relative 'lib/philiprehberger/expiring_map/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-expiring_map'
  spec.version       = Philiprehberger::ExpiringMap::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Thread-safe hash with per-key TTL and automatic expiration'
  spec.description   = 'A thread-safe hash map where each key has its own TTL, with automatic expiration, ' \
                       'max size eviction, expiration callbacks, and Enumerable support.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-expiring-map'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
