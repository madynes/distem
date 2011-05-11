module Wrekavoc
  module Node

    class Admin

      PATH_CGROUP='/dev/cgroup'
      NAME_BRIDGE='br0'
      
      def self.init_node
        set_bridge()
        set_cgroups()
      end

      def self.get_default_iface
        cmdret = Lib::Shell.run("/sbin/route") 
        # | grep 'default' | awk '{print \$8}' | tr -d '\n'")
        ret=""
        cmdret.each_line { |s| ret=s.split[7] if s.include?("default") }
        return ret
      end 

      def self.get_iface_addr(iface)
        cmdret = Lib::Shell.run("/sbin/ifconfig #{iface}") 
        # | grep 'inet addr' | awk '{print \$2}' | cut -d':' -f2 | tr -d '\n'")
        ret=""
        cmdret.each_line { |s| ret=s.split[1].split(":")[1] if s.include?("inet addr") }
        return ret
      end

      def self.get_default_addr()
        iface = self.get_default_iface()
        self.get_iface_addr(iface).strip
      end

      def self.set_bridge
        iface = self.get_default_iface()
        addr = self.get_default_addr()

        str = Lib::Shell.run("ifconfig")

        unless str.include?("#{NAME_BRIDGE}")
          Lib::Shell.run("brctl addbr #{NAME_BRIDGE}")
          Lib::Shell.run("brctl setfd #{NAME_BRIDGE} 0")
          Lib::Shell.run("ifconfig #{NAME_BRIDGE} #{addr} promisc up")
          Lib::Shell.run("brctl addif #{NAME_BRIDGE} #{iface}")
          Lib::Shell.run("ifconfig #{iface} 0.0.0.0 up")
        end
      end

      def self.set_cgroups
        unless File.exists?("#{PATH_CGROUP}")
          Lib::Shell.run("mkdir #{PATH_CGROUP}")
          Lib::Shell.run("mount -t cgroup cgroup #{PATH_CGROUP}")
        end
      end
    end

  end
end
