# frozen_string_literal: true

require_relative 'entry'

module Philiprehberger
  module ExpiringMap
    # Thread-safe hash with per-key TTL and automatic expiration
    class Map
      include Enumerable

      # @param default_ttl [Numeric] default TTL in seconds for new entries
      # @param max_size [Integer, nil] maximum number of entries, nil for unlimited
      def initialize(default_ttl: 60, max_size: nil)
        @default_ttl = default_ttl
        @max_size = max_size
        @store = {}
        @mutex = Mutex.new
        @on_expire_callback = nil
        @hits = 0
        @misses = 0
        @expirations = 0
        @evictions = 0
      end

      # Store a value with an optional per-key TTL
      #
      # @param key [Object] the key
      # @param value [Object] the value
      # @param ttl [Numeric, nil] TTL in seconds, uses default if nil
      # @return [Object] the stored value
      def set(key, value, ttl: nil)
        ttl ||= @default_ttl
        expires_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + ttl

        @mutex.synchronize do
          sweep_expired
          evict_oldest if @max_size && @store.size >= @max_size && !@store.key?(key)
          @store[key] = Entry.new(value, expires_at)
        end

        value
      end

      # Retrieve a value by key
      #
      # @param key [Object] the key
      # @return [Object, nil] the value or nil if expired/missing
      def get(key)
        @mutex.synchronize do
          entry = @store[key]
          unless entry
            @misses += 1
            return nil
          end

          if entry.expired?
            @expirations += 1
            @misses += 1
            fire_expire(key, entry.value)
            @store.delete(key)
            return nil
          end

          @hits += 1
          entry.value
        end
      end

      # Delete a key
      #
      # @param key [Object] the key
      # @return [Object, nil] the deleted value or nil
      def delete(key)
        @mutex.synchronize do
          entry = @store.delete(key)
          entry&.value
        end
      end

      # Return remaining TTL for a key
      #
      # @param key [Object] the key
      # @return [Float, nil] remaining TTL in seconds or nil if missing
      def ttl(key)
        @mutex.synchronize do
          entry = @store[key]
          return nil unless entry
          return nil if entry.expired?

          entry.ttl
        end
      end

      # Reset the TTL for a key to the default
      #
      # @param key [Object] the key
      # @return [Boolean] true if the key exists and was touched
      def touch(key)
        @mutex.synchronize do
          entry = @store[key]
          return false unless entry
          return false if entry.expired?

          entry.expires_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @default_ttl
          true
        end
      end

      # Return the number of non-expired entries
      #
      # @return [Integer] the count
      def size
        @mutex.synchronize do
          sweep_expired
          @store.size
        end
      end

      # Register a callback for expired entries
      #
      # @yield [key, value] called when an entry expires
      def on_expire(&block)
        @mutex.synchronize do
          @on_expire_callback = block
        end
      end

      # Remove all entries
      #
      # @return [void]
      def clear
        @mutex.synchronize do
          @store.clear
        end
      end

      # Iterate over non-expired entries
      #
      # @yield [key, value] each non-expired entry
      # @return [Enumerator] if no block given
      def each(&block)
        pairs = @mutex.synchronize do
          sweep_expired
          @store.map { |k, e| [k, e.value] }
        end

        return pairs.each unless block

        pairs.each(&block)
      end

      # Return statistics about the map
      #
      # @return [Hash] stats with hits, misses, expirations, evictions, size
      def stats
        @mutex.synchronize do
          sweep_expired
          {
            hits: @hits,
            misses: @misses,
            expirations: @expirations,
            evictions: @evictions,
            size: @store.size
          }
        end
      end

      # Bulk insert from a hash
      #
      # @param hash [Hash] key-value pairs to insert
      # @param ttl [Numeric, nil] TTL for all entries, uses default if nil
      # @return [void]
      def set_many(hash, ttl: nil)
        hash.each { |k, v| set(k, v, ttl: ttl) }
      end

      # Bulk retrieve values by keys
      #
      # @param keys [Array<Object>] keys to retrieve
      # @return [Hash] key => value (nil for misses)
      def get_many(*keys)
        keys.flatten.to_h { |k| [k, get(k)] }
      end

      # Remove entries where the block returns true
      #
      # @yield [key, value] each non-expired entry
      # @return [Integer] count of deleted entries
      def delete_if(&block)
        raise ArgumentError, 'block required' unless block

        @mutex.synchronize do
          sweep_expired
          count = 0
          @store.delete_if do |key, entry|
            if block.call(key, entry.value)
              count += 1
              true
            else
              false
            end
          end
          count
        end
      end

      # Return all non-expired keys
      #
      # @return [Array<Object>] array of keys
      def keys
        @mutex.synchronize do
          sweep_expired
          @store.keys
        end
      end

      # Return all non-expired values
      #
      # @return [Array<Object>] array of values
      def values
        @mutex.synchronize do
          sweep_expired
          @store.values.map(&:value)
        end
      end

      private

      # Remove all expired entries, firing callbacks
      def sweep_expired
        @store.delete_if do |key, entry|
          if entry.expired?
            @expirations += 1
            fire_expire(key, entry.value)
            true
          else
            false
          end
        end
      end

      # Evict the oldest entry when at capacity
      def evict_oldest
        oldest_key = @store.keys.first
        return unless oldest_key

        entry = @store.delete(oldest_key)
        return unless entry

        @evictions += 1
        fire_expire(oldest_key, entry.value)
      end

      # Fire the expiration callback if registered
      #
      # @param key [Object] the expired key
      # @param value [Object] the expired value
      def fire_expire(key, value)
        @on_expire_callback&.call(key, value)
      end
    end
  end
end
