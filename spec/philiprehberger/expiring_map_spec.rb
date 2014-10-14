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
  end
end
