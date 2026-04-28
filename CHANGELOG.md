# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-04-27

### Added
- `Map#purge_expired!` — actively sweep expired entries and return the count removed; fires `on_expire` callbacks. Useful for explicit cleanup in long-running processes that read sparingly.
- `Map#expired?(key)` — predicate for whether an entry is present-but-expired without deleting it or firing `on_expire`. Distinct from `get(key).nil?`, which can't tell "missing" from "expired".

## [0.3.0] - 2026-04-17

### Added
- `Map#fetch(key, ttl: nil) { block }` atomically memoizes the block result on miss

## [0.2.0] - 2026-04-03

### Added
- Statistics tracking via `stats` (hits, misses, expirations, evictions)
- Bulk operations: `set_many`, `get_many`
- `delete_if` for predicate-based removal
- `keys` and `values` methods for non-expired entries

## [0.1.5] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.1.4] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.1.3] - 2026-03-24

### Fixed
- Standardize README code examples to use double-quote require statements

## [0.1.2] - 2026-03-24

### Fixed
- Fix Installation section quote style to double quotes

## [0.1.1] - 2026-03-22

### Changed

- Expand test coverage to 30+ examples covering touch TTL reset, per-key TTL, max size eviction, on_expire callbacks, enumerable with expired entries, overwrite TTL reset, size excluding expired, and edge cases

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Thread-safe hash with per-key TTL and automatic expiration
- Configurable default TTL and max size with oldest-entry eviction
- Expiration callbacks via on_expire
- Touch to reset TTL and TTL query per key
- Enumerable support for iterating non-expired entries
