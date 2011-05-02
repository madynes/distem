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
        cmdret = Lib::Shell.run("/sbin/route") 
        # | grep 'default' | awk '{print \$8}' | tr -d '\n'")
        ret=""
        cmdret.each_line { |s| ret=s.split[7] if s.include?("default") }
        return ret
      end 

      def get_iface_addr(iface)
        cmdret = Lib::Shell.run("/sbin/ifconfig #{iface}") 
        # | grep 'inet addr' | awk '{print \$2}' | cut -d':' -f2 | tr -d '\n'")
        ret=""
        cmdret.each_line { |s| ret=s.split[1].split(":")[1] if s.include?("inet addr") }
        return ret
      end

      def set_bridge
        iface = get_default_iface()
        addr = get_iface_addr(iface)

        Lib::Shell.run("brctl addbr br0")
        Lib::Shell.run("brctl setfd br0 0")
        Lib::Shell.run("ifconfig br0 #{addr} promisc up")
        Lib::Shell.run("brctl addif br0 #{iface}")
        Lib::Shell.run("ifconfig #{iface} 0.0.0.0 up")
      end

      def set_cgroups
        Lib::Shell.run("mkdir #{PATH_CGROUP}")
        Lib::Shell.run("mount -t cgroup cgroup #{PATH_CGROUP}")
      end
    end

  end
end
