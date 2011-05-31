require 'wrekavoc'

module Wrekavoc
  module Node

    class Admin

      PATH_CGROUP='/dev/cgroup'
      MAX_IFACES=32
      
      def self.init_node
        Lib::NetTools.set_bridge()
        Lib::NetTools.set_ifb(MAX_IFACES)
        set_cgroups()
      end

      def self.set_cgroups
        unless File.exists?("#{PATH_CGROUP}")
          Lib::Shell.run("mkdir #{PATH_CGROUP}")
          Lib::Shell.run("mount -t cgroup cgroup #{PATH_CGROUP}")
        end
      end

      def self.set_iface(iface)
        Lib::Shell.run("ethtool -K #{iface} gso off")
        Lib::Shell.run("ethtool -K #{iface} tso off")
      end
    end

  end
end
