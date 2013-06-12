module Distem
  module Resource

    # Abstract representation of the physical memory resource
    class Memory
      # The capacity of the RAM (in MB)
      attr_accessor :capacity
      # The capacity of the Swap (in MB)
      attr_accessor :swap
      # The allocated RAM (in MB)
      attr_accessor :allocated_capacity
      # The allocated Swap (in MB)
      attr_accessor :allocated_swap

      # Create a new Memory
      def initialize(capacity=0,swap=0)
        @capacity = capacity
        @swap = swap
        @allocated_capacity = 0
        @allocated_swap = 0
        @capacity_lock = Mutex.new
        @swap_lock = Mutex.new
      end

      def allocate(opts)
        if ((opts[:mem] && (opts[:mem].to_i > (@capacity - @allocated_capacity))) ||
            (opts[:swap] && (opts[:swap].to_i > (@swap - @allocated_swap))))
          raise Lib::UnavailableResourceError
        end
        if opts[:mem]
          @capacity_lock.synchronize {
            @allocated_capacity += opts[:mem].to_i
          }
        end
        if opts[:swap]
          @swap_lock.synchronize {
            @allocated_swap += opts[:swap].to_i
          }
        end
      end

      def deallocate(opts)
        if opts[:mem]
          @capacity_lock.synchronize {
            @allocated_capacity -= opts[:mem].to_i
          }
        end
        if opts[:swap]
          @swap_lock.synchronize {
            @allocated_swap -= opts[:swap].to_i
          }
        end
        raise Lib::DistemError if ((@allocated_capacity < 0) || (@allocated_swap < 0))
      end

      def get_free_capacity
        return @capacity - @allocated_capacity
      end

      def get_free_swap
        return @swap - @allocated_swap
      end
    end
  end
end
