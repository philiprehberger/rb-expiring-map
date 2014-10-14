# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
