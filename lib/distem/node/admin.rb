require 'distem'

module Distem
  module Node

    # Class that allow to set up a physical node resources (init cgroups, tc, ...)
    class Admin

      # The directory used to store temporary files
      PATH_DISTEMTMP='/tmp/distem/'
      # The cgroups directory to use
      PATH_CGROUP='/dev/cgroup'
      # The maximum number of network interfaces (used with ifb)
      MAX_IFACES=64
      
      # Initialize a physical node (set cgroups, bridge, ifb, fill the PNode cpu and memory informations, ...)
      # ==== Attributes
      # * +pnode+ The PNode object that will be filled with different informations
      #
      def self.init_node(pnode,vnodes_max=MAX_IFACES)
        Lib::NetTools.set_bridge()
        Lib::NetTools.set_ifb(vnodes_max)
        set_cgroups()
        Lib::CPUTools.set_resource(pnode.cpu)
        Lib::MemoryTools.set_resource(pnode.memory)
      end

      # Clean and unset all content set by the system (remove cgroups, bridge, ifb, temporary files, ...)
      # ==== Attributes
      #
      def self.quit_node
        Lib::NetTools.unset_bridge()
        Lib::NetTools.unset_ifb()
        unset_cgroups()
        Lib::Shell.run("rm -R #{PATH_DISTEMTMP}") if File.exists?(PATH_DISTEMTMP)
      end

      # Initialize (mount) the CGroup filesystem that will be used by the system (LXC, ...)
      def self.set_cgroups
        unless File.exists?("#{PATH_CGROUP}")
          Lib::Shell.run("mkdir #{PATH_CGROUP}")
          Lib::Shell.run("mount -t cgroup cgroup #{PATH_CGROUP}")
        end
      end

      # Clean (umount) the CGroup filesystem used by the system
      def self.unset_cgroups
        if File.exists?("#{PATH_CGROUP}")
          Lib::Shell.run("umount #{PATH_CGROUP}")
          Lib::Shell.run("rmdir #{PATH_CGROUP}")
        end
      end

      # Set up a network interface to work with the different tools (i.e. tcp-tso&gso set to off in order to work with TC TBF)
      def self.set_iface(iface)
        Lib::Shell.run("ethtool -K #{iface} gso off")
        Lib::Shell.run("ethtool -K #{iface} tso off")
      end
    end

  end
end
