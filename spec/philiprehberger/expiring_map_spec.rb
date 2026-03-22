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
    end
  end
end
