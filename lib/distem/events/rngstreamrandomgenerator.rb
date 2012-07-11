module Distem
  module Events
    class RngStreamRandomGenerator < RandomGenerator

      # Class which use a RngStream to generate random numbers
      # Better from a statistical point of view, because each stream
      # is independant. This can't be the case with the rand function,
      # because there is only one stream.

      def initialize(seed = nil)
        @stream = RandomExtension::RngStream.new
        if seed
          if seed.is_a?(Array)
            raise "Invalid seed array size, must be >= 6" if seed.length < 6
            @stream.set_seed(seed)
          elsif seed.is_a?(Numeric)
            seed_array = [ seed, seed, seed, seed, seed, seed]
            @stream.set_seed(seed_array)
          else
            raise "Invalid seed type"
          end
        end
      end

      def rand_U01
        return @stream.randU01
      end

      def advance_state(displacement)
        @stream.advance_state(displacement)
        return self
      end

    end
  end
end
