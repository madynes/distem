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
        Lib::Shell.run("route | grep 'default' | awk '{print \$8}' | tr -d '\n'")
      end 

      def get_iface_addr(iface)
        # >>> TODO: check command line return 
        Lib::Shell.run("ifconfig #{iface} | grep 'inet addr' | awk '{print \$2}' | cut -d':' -f2 | tr -d '\n'")
      end

      def set_bridge
        iface = get_default_iface()
        addr = get_iface_addr(iface)

        # >>> TODO: check command line return 
        Lib::Shell.run("brctl addbr br0")
        Lib::Shell.run("brctl setfd br0 0")
        Lib::Shell.run("ifconfig br0 #{addr} promisc up")
        Lib::Shell.run("brctl addif br0 #{iface}")
        Lib::Shell.run("ifconfig #{iface} 0.0.0.0 up")
      end

      def set_cgroups
        # >>> TODO: check command line return 
        Lib::Shell.run("mkdir #{PATH_CGROUP}")
        Lib::Shell.run("mount -t cgroup cgroup #{PATH_CGROUP}")
      end
    end

  end
end
