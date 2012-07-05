module Distem
  module Events
    class SimpleRandomGenerator < RandomGenerator

      # Class which badly generates random numbers
      # All the instances of this class use the same random generator,
      # embedded in the Kernel module
      # This should not be used.

      def initialize(seed = nil)
        if seed
          # Set the seed for everyone uses this class (!)
          if seed.is_a?(Array)
            tmp_seed = 0
            seed.each do |x| tmp_seed += x end
            seed = tmp_seed
          end
          srand(seed)
        end
      end

      def rand_U01
        return rand
      end

      def advance_state(displacement)
        # Not supported, so, does nothing...
      end

    end
  end
end
