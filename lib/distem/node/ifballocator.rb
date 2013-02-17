#require 'distem'

module Distem
  module Node

    # Class that manages the allocation of IFB devices on a pnode
    class IFBAllocator
      
      # Initialize the allocator. Will automatically guess the number of ifb devices.
      def initialize
        @allocmutex = Mutex::new
        @ifbs = Lib::Shell.run('ip link list').scan(/: (ifb\d+):/).map { |e| e[0] }
      end

      # Get an IFB device name (e.g. "ifb42")
      def get_ifb
        @allocmutex.lock
            raise "No more IFB devices" if @ifbs.empty?  # should never happen since there's
               # a safeguard at vnode creation time
          ifb = @ifbs.shift
        @allocmutex.unlock
        # make sure the IFB device is up
        Lib::Shell.run("ip link set dev #{ifb} up")
        return ifb
      end
      
      # Free an IFB device
      def free_ifb(ifb)
        @allocmutex.lock
          @ifbs.push(ifb)
        @allocmutex.unlock
      end
    end
  end
end
