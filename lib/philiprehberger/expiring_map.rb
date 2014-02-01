# frozen_string_literal: true

require_relative 'expiring_map/version'
require_relative 'expiring_map/map'

module Philiprehberger
  module ExpiringMap
    class Error < StandardError; end

    # Create a new expiring map
    #
    # @param default_ttl [Numeric] default TTL in seconds
    # @param max_size [Integer, nil] maximum number of entries
    # @return [Map] a new expiring map instance
    def self.new(default_ttl: 60, max_size: nil)
      Map.new(default_ttl: default_ttl, max_size: max_size)
    end
  end
end
