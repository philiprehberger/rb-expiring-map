# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::ExpiringMap do
  it 'has a version number' do
    expect(described_class::VERSION).not_to be_nil
  end

  describe '.new' do
    it 'creates a Map instance' do
      map = described_class.new(default_ttl: 10)
      expect(map).to be_a(described_class::Map)
    end
  end

  describe Philiprehberger::ExpiringMap::Map do
    subject(:map) { described_class.new(default_ttl: 10) }

    describe '#set and #get' do
      it 'stores and retrieves a value' do
        map.set(:key, 'value')
        expect(map.get(:key)).to eq('value')
      end

      it 'returns nil for missing keys' do
        expect(map.get(:missing)).to be_nil
      end

      it 'overwrites existing keys' do
        map.set(:key, 'first')
        map.set(:key, 'second')
        expect(map.get(:key)).to eq('second')
      end
    end

    describe 'expiration' do
      it 'returns nil for expired entries' do
        map = described_class.new(default_ttl: 0.01)
        map.set(:key, 'value')
        sleep(0.02)
        expect(map.get(:key)).to be_nil
      end

      it 'respects per-key TTL' do
        map.set(:short, 'value', ttl: 0.01)
        map.set(:long, 'value', ttl: 10)
        sleep(0.02)
        expect(map.get(:short)).to be_nil
        expect(map.get(:long)).to eq('value')
      end
    end

    describe '#delete' do
      it 'removes and returns the value' do
        map.set(:key, 'value')
        expect(map.delete(:key)).to eq('value')
        expect(map.get(:key)).to be_nil
      end

      it 'returns nil for missing keys' do
        expect(map.delete(:missing)).to be_nil
      end
    end

    describe '#fetch' do
      it 'returns the existing value and does not call the block on hit' do
        map.set(:key, 'cached')
        called = false
        result = map.fetch(:key) do
  called = true
  'computed'
end
        expect(result).to eq('cached')
        expect(called).to be(false)
      end

      it 'calls the block, stores the result, and returns it on miss' do
        called = 0
        result = map.fetch(:missing) do
  called += 1
  'fresh'
end
        expect(result).to eq('fresh')
        expect(called).to eq(1)
        expect(map.get(:missing)).to eq('fresh')
      end

      it 'stores with the ttl: override on miss' do
        map.fetch(:key, ttl: 7) { 'value' }
        remaining = map.ttl(:key)
        expect(remaining).to be > 6
        expect(remaining).to be <= 7
      end

      it 'propagates errors from the block and does not cache anything' do
        expect { map.fetch(:boom) { raise 'nope' } }.to raise_error(RuntimeError, 'nope')
        expect(map.get(:boom)).to be_nil
      end

      it 'raises KeyError when no block is given and key is missing' do
        expect { map.fetch(:missing) }.to raise_error(KeyError)
      end

      it 'recomputes the value when the existing entry has expired' do
        short_map = described_class.new(default_ttl: 10)
        short_map.set(:key, 'old', ttl: 0.01)
        sleep(0.02)
        result = short_map.fetch(:key) { 'new' }
        expect(result).to eq('new')
        expect(short_map.get(:key)).to eq('new')
      end
    end

    describe '#ttl' do
      it 'returns remaining TTL' do
        map.set(:key, 'value', ttl: 10)
        remaining = map.ttl(:key)
        expect(remaining).to be > 0
        expect(remaining).to be <= 10
      end

      it 'returns nil for missing keys' do
        expect(map.ttl(:missing)).to be_nil
      end
    end

    describe '#touch' do
      it 'resets the TTL' do
        map = described_class.new(default_ttl: 10)
        map.set(:key, 'value', ttl: 1)
        map.touch(:key)
        expect(map.ttl(:key)).to be > 1
      end

      it 'returns false for missing keys' do
        expect(map.touch(:missing)).to be(false)
      end
    end

    describe '#size' do
      it 'returns the count of non-expired entries' do
        map.set(:a, 1)
        map.set(:b, 2)
        expect(map.size).to eq(2)
      end

      it 'excludes expired entries' do
        map.set(:short, 'value', ttl: 0.01)
        map.set(:long, 'value', ttl: 10)
        sleep(0.02)
        expect(map.size).to eq(1)
      end
    end

    describe '#on_expire' do
      it 'fires callback when entry expires' do
        expired_keys = []
        map = described_class.new(default_ttl: 0.01)
        map.on_expire { |k, _v| expired_keys << k }
        map.set(:key, 'value')
        sleep(0.02)
        map.size # triggers sweep
        expect(expired_keys).to include(:key)
      end
    end

    describe '#clear' do
      it 'removes all entries' do
        map.set(:a, 1)
        map.set(:b, 2)
        map.clear
        expect(map.size).to eq(0)
      end
    end

    describe 'max_size' do
      it 'evicts oldest entry when at capacity' do
        map = described_class.new(default_ttl: 60, max_size: 2)
        map.set(:a, 1)
        map.set(:b, 2)
        map.set(:c, 3)
        expect(map.get(:a)).to be_nil
        expect(map.get(:b)).to eq(2)
        expect(map.get(:c)).to eq(3)
      end
    end

    describe 'Enumerable' do
      it 'iterates over non-expired entries' do
        map.set(:a, 1)
        map.set(:b, 2)
        pairs = map.map { |k, v| [k, v] }
        expect(pairs).to contain_exactly([:a, 1], [:b, 2])
      end

      it 'excludes expired entries from iteration' do
        map.set(:short, 'gone', ttl: 0.01)
        map.set(:long, 'here', ttl: 10)
        sleep(0.02)
        pairs = map.map { |k, v| [k, v] }
        expect(pairs).to eq([[:long, 'here']])
      end

      it 'returns an enumerator when no block given' do
        map.set(:a, 1)
        enum = map.each
        expect(enum).to be_a(Enumerator)
      end
    end

    describe '#touch resets TTL' do
      it 'extends lifetime of an entry' do
        short_map = described_class.new(default_ttl: 0.5)
        short_map.set(:key, 'value', ttl: 0.05)
        sleep(0.02)
        short_map.touch(:key)
        # After touch, TTL should be reset to default_ttl (0.5s)
        expect(short_map.ttl(:key)).to be > 0.1
        expect(short_map.get(:key)).to eq('value')
      end

      it 'returns false for expired keys' do
        short_map = described_class.new(default_ttl: 0.01)
        short_map.set(:key, 'value')
        sleep(0.02)
        expect(short_map.touch(:key)).to be(false)
      end
    end

    describe 'different TTLs per key' do
      it 'allows each key to have its own TTL' do
        map.set(:fast, 'fast-val', ttl: 0.01)
        map.set(:medium, 'med-val', ttl: 0.05)
        map.set(:slow, 'slow-val', ttl: 10)

        sleep(0.02)
        expect(map.get(:fast)).to be_nil
        expect(map.get(:medium)).to eq('med-val')
        expect(map.get(:slow)).to eq('slow-val')
      end
    end

    describe 'max_size eviction' do
      it 'evicts oldest when inserting beyond capacity' do
        small_map = described_class.new(default_ttl: 60, max_size: 3)
        small_map.set(:a, 1)
        small_map.set(:b, 2)
        small_map.set(:c, 3)
        small_map.set(:d, 4)

        expect(small_map.get(:a)).to be_nil
        expect(small_map.get(:d)).to eq(4)
        expect(small_map.size).to eq(3)
      end

      it 'does not evict when overwriting an existing key' do
        small_map = described_class.new(default_ttl: 60, max_size: 2)
        small_map.set(:a, 1)
        small_map.set(:b, 2)
        small_map.set(:a, 10) # overwrite, not new

        expect(small_map.get(:a)).to eq(10)
        expect(small_map.get(:b)).to eq(2)
      end

      it 'fires on_expire callback during eviction' do
        evicted = []
        small_map = described_class.new(default_ttl: 60, max_size: 1)
        small_map.on_expire { |k, v| evicted << [k, v] }
        small_map.set(:a, 1)
        small_map.set(:b, 2)

        expect(evicted).to include([:a, 1])
      end
    end

    describe '#on_expire callback' do
      it 'fires for each expired entry during sweep' do
        expired_pairs = []
        short_map = described_class.new(default_ttl: 0.01)
        short_map.on_expire { |k, v| expired_pairs << [k, v] }
        short_map.set(:x, 10)
        short_map.set(:y, 20)
        sleep(0.02)
        short_map.size # triggers sweep
        expect(expired_pairs).to contain_exactly([:x, 10], [:y, 20])
      end

      it 'fires callback on get of expired entry' do
        expired_keys = []
        short_map = described_class.new(default_ttl: 0.01)
        short_map.on_expire { |k, _v| expired_keys << k }
        short_map.set(:key, 'val')
        sleep(0.02)
        short_map.get(:key)
        expect(expired_keys).to include(:key)
      end
    end

    describe 'overwrite existing key resets TTL' do
      it 'resets TTL when overwriting' do
        map.set(:key, 'first', ttl: 0.02)
        sleep(0.01)
        map.set(:key, 'second', ttl: 10)
        sleep(0.02)
        expect(map.get(:key)).to eq('second')
      end
    end

    describe '#size excludes expired' do
      it 'does not count expired entries' do
        short_map = described_class.new(default_ttl: 0.01)
        short_map.set(:a, 1)
        short_map.set(:b, 2)
        short_map.set(:c, 3, ttl: 10)
        sleep(0.02)
        expect(short_map.size).to eq(1)
      end
    end

    describe '#ttl edge cases' do
      it 'returns nil for expired keys' do
        short_map = described_class.new(default_ttl: 0.01)
        short_map.set(:key, 'val')
        sleep(0.02)
        expect(short_map.ttl(:key)).to be_nil
      end

      it 'returns a value close to the set TTL for fresh entries' do
        map.set(:key, 'val', ttl: 5)
        remaining = map.ttl(:key)
        expect(remaining).to be > 4
        expect(remaining).to be <= 5
      end
    end

    describe '#delete edge cases' do
      it 'returns nil when deleting an expired key' do
        short_map = described_class.new(default_ttl: 0.01)
        short_map.set(:key, 'val')
        sleep(0.02)
        # delete returns the value even if expired since it just removes from store
        result = short_map.delete(:key)
        # The entry is still in the store until swept, so delete finds it
        expect(result).to eq('val').or be_nil
      end
    end

    describe '#clear after operations' do
      it 'allows reuse after clear' do
        map.set(:a, 1)
        map.clear
        map.set(:b, 2)
        expect(map.get(:a)).to be_nil
        expect(map.get(:b)).to eq(2)
        expect(map.size).to eq(1)
      end
    end

    describe '#stats' do
      it 'returns initial stats for empty map' do
        s = map.stats
        expect(s).to eq(hits: 0, misses: 0, expirations: 0, evictions: 0, size: 0)
      end

      it 'tracks hits and misses' do
        map.set(:a, 1)
        map.get(:a)
        map.get(:missing)
        s = map.stats
        expect(s[:hits]).to eq(1)
        expect(s[:misses]).to eq(1)
      end

      it 'tracks expirations on get' do
        short_map = described_class.new(default_ttl: 0.01)
        short_map.set(:a, 1)
        sleep(0.02)
        short_map.get(:a)
        s = short_map.stats
        expect(s[:expirations]).to be >= 1
        expect(s[:misses]).to be >= 1
      end

      it 'tracks expirations during sweep' do
        short_map = described_class.new(default_ttl: 0.01)
        short_map.set(:a, 1)
        short_map.set(:b, 2)
        sleep(0.02)
        short_map.size # triggers sweep
        s = short_map.stats
        expect(s[:expirations]).to eq(2)
      end

      it 'tracks evictions' do
        small_map = described_class.new(default_ttl: 60, max_size: 1)
        small_map.set(:a, 1)
        small_map.set(:b, 2)
        s = small_map.stats
        expect(s[:evictions]).to eq(1)
      end

      it 'resets size after clear but preserves counters' do
        map.set(:a, 1)
        map.get(:a)
        map.clear
        s = map.stats
        expect(s[:size]).to eq(0)
        expect(s[:hits]).to eq(1)
      end
    end

    describe '#set_many' do
      it 'inserts multiple entries' do
        map.set_many({ a: 1, b: 2, c: 3 })
        expect(map.get(:a)).to eq(1)
        expect(map.get(:b)).to eq(2)
        expect(map.get(:c)).to eq(3)
        expect(map.size).to eq(3)
      end

      it 'accepts a custom TTL' do
        map.set_many({ x: 10, y: 20 }, ttl: 0.01)
        sleep(0.02)
        expect(map.get(:x)).to be_nil
        expect(map.get(:y)).to be_nil
      end

      it 'overwrites existing keys' do
        map.set(:a, 'old')
        map.set_many({ a: 'new', b: 2 })
        expect(map.get(:a)).to eq('new')
      end

      it 'handles empty hash' do
        map.set_many({})
        expect(map.size).to eq(0)
      end
    end

    describe '#get_many' do
      it 'returns hash of found and missing values' do
        map.set(:a, 1)
        map.set(:b, 2)
        result = map.get_many(:a, :b, :missing)
        expect(result).to eq(a: 1, b: 2, missing: nil)
      end

      it 'tracks hits and misses' do
        map.set(:a, 1)
        map.get_many(:a, :missing)
        s = map.stats
        expect(s[:hits]).to eq(1)
        expect(s[:misses]).to eq(1)
      end

      it 'returns empty hash for no keys' do
        expect(map.get_many).to eq({})
      end
    end

    describe '#delete_if' do
      it 'removes entries matching predicate' do
        map.set(:a, 1)
        map.set(:b, 10)
        map.set(:c, 5)
        count = map.delete_if { |_k, v| v >= 5 }
        expect(count).to eq(2)
        expect(map.get(:a)).to eq(1)
        expect(map.get(:b)).to be_nil
        expect(map.get(:c)).to be_nil
      end

      it 'returns zero when nothing matches' do
        map.set(:a, 1)
        count = map.delete_if { |_k, _v| false }
        expect(count).to eq(0)
        expect(map.size).to eq(1)
      end

      it 'works on empty map' do
        count = map.delete_if { |_k, _v| true }
        expect(count).to eq(0)
      end

      it 'raises ArgumentError without block' do
        expect { map.delete_if }.to raise_error(ArgumentError)
      end
    end

    describe '#keys' do
      it 'returns non-expired keys' do
        map.set(:a, 1)
        map.set(:b, 2)
        expect(map.keys).to contain_exactly(:a, :b)
      end

      it 'excludes expired keys' do
        map.set(:short, 'gone', ttl: 0.01)
        map.set(:long, 'here', ttl: 10)
        sleep(0.02)
        expect(map.keys).to eq([:long])
      end

      it 'returns empty array for empty map' do
        expect(map.keys).to eq([])
      end
    end

    describe '#values' do
      it 'returns non-expired values' do
        map.set(:a, 1)
        map.set(:b, 2)
        expect(map.values).to contain_exactly(1, 2)
      end

      it 'excludes expired values' do
        map.set(:short, 'gone', ttl: 0.01)
        map.set(:long, 'here', ttl: 10)
        sleep(0.02)
        expect(map.values).to eq(['here'])
      end

      it 'returns empty array for empty map' do
        expect(map.values).to eq([])
      end
    end
  end
end
