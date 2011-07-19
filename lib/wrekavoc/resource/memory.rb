module Wrekavoc
  module Resource

    class Memory
      attr_accessor :capacity,:swap

      def initialize(capacity=0,swap=0)
        @capacity = capacity
        @swap = swap
      end
    end

  end
end
