# frozen_string_literal: true

module Philiprehberger
  module ExpiringMap
    # Internal entry storing a value with its expiration time
    class Entry
      # @param value [Object] the stored value
      # @param expires_at [Float] monotonic time when the entry expires
      def initialize(value, expires_at)
        @value = value
        @expires_at = expires_at
      end

      # @return [Object] the stored value
      attr_reader :value

      # @return [Float] monotonic time when the entry expires
      attr_accessor :expires_at

      # Check if the entry has expired
      #
      # @return [Boolean] true if expired
      def expired?
        Process.clock_gettime(Process::CLOCK_MONOTONIC) >= @expires_at
      end

      # Return remaining TTL in seconds
      #
      # @return [Float] seconds until expiration, 0 if expired
      def ttl
        remaining = @expires_at - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        remaining.positive? ? remaining : 0.0
      end
    end
  end
end
