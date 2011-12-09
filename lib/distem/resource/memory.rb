module Distem
  module Resource

    # Abstract representation of the physical memory resource
    class Memory
      # The capacity of the RAM (in MB)
      attr_accessor :capacity
      # The capacity of the Swap (in MB)
      attr_accessor :swap

      # Create a new Memory
      def initialize(capacity=0,swap=0)
        @capacity = capacity
        @swap = swap
      end
    end

  end
end
