module Wrekavoc
  module Node

    class Admin

      PATH_CGROUP='/dev/cgroup'
      
      def initialize
      end

      def init_node
        set_bridge()
        set_cgroups()
      end

      def get_default_iface
        # >>> TODO: check command line return 
        `route | grep 'default' | awk '{print $8}' | tr -d '\n'`
      end 

      def get_iface_addr(iface)
        # >>> TODO: check command line return 
        `ifconfig "#{iface}" | grep 'inet addr' | awk '{print $2}' | cut -d':' -f2 | tr -d '\n'`
      end

      def set_bridge
        iface = get_default_iface()
        addr = get_iface_addr(iface)

        # >>> TODO: check command line return 
        `brctl addbr br0`
        `brctl setfd br0 0`
        `ifconfig br0 #{addr} promisc up`
        `brctl addif br0 #{iface}`
        `ifconfig #{iface} 0.0.0.0 up`
      end

      def set_cgroups
        # >>> TODO: check command line return 
        `mkdir #{PATH_CGROUP}`
        `mount -t cgroup cgroup #{PATH_CGROUP}`
      end
    end

  end
end
