# philiprehberger-expiring_map

[![Tests](https://github.com/philiprehberger/rb-expiring-map/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-expiring-map/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-expiring_map.svg)](https://rubygems.org/gems/philiprehberger-expiring_map)
[![License](https://img.shields.io/github/license/philiprehberger/rb-expiring-map)](LICENSE)

Thread-safe hash with per-key TTL and automatic expiration

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-expiring_map"
```

Or install directly:

```bash
gem install philiprehberger-expiring_map
```

## Usage

```ruby
require "philiprehberger/expiring_map"

cache = Philiprehberger::ExpiringMap.new(default_ttl: 300)
cache.set(:session, 'abc123')
cache.get(:session)  # => 'abc123'
```

### Per-Key TTL

```ruby
cache.set(:token, 'xyz', ttl: 60)    # expires in 60 seconds
cache.set(:config, data, ttl: 3600)   # expires in 1 hour
cache.ttl(:token)                      # => remaining seconds
```

### Max Size with Eviction

```ruby
cache = Philiprehberger::ExpiringMap.new(default_ttl: 300, max_size: 1000)
# Oldest entries are evicted when capacity is reached
```

### Expiration Callback

```ruby
cache.on_expire do |key, value|
  logger.info("Expired: #{key}")
end
```

### Touch to Reset TTL

```ruby
cache.set(:session, data)
cache.touch(:session)  # resets TTL to default
```

### Enumerable

```ruby
cache.each { |key, value| puts "#{key}: #{value}" }
cache.select { |_k, v| v > 10 }
```

## API

| Method | Description |
|--------|-------------|
| `.new(default_ttl:, max_size:)` | Create a new expiring map |
| `#set(key, value, ttl:)` | Store a value with optional per-key TTL |
| `#get(key)` | Retrieve a value, nil if expired or missing |
| `#delete(key)` | Remove and return a value |
| `#ttl(key)` | Return remaining TTL in seconds |
| `#touch(key)` | Reset TTL to default |
| `#size` | Count of non-expired entries |
| `#on_expire { \|k, v\| }` | Register expiration callback |
| `#clear` | Remove all entries |
| `#each { \|k, v\| }` | Iterate over non-expired entries |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
