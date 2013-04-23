#require 'distem'

module Distem
  module Node

    # Class that allow to set up a physical node resources (init cgroups, tc, ...)
    class Admin
      # The directory used to store distem logs
      PATH_DISTEM_LOGS='/var/log/distem/'
      # The directory used to store temporary files
      PATH_DISTEMTMP='/tmp/distem/'
      # The cgroups directory to use
      PATH_CGROUP='/dev/cgroup'
      # The default maximum number of virual network interfaces (used with ifb)
      MAX_VIFACES=64
      # The default maximum number of PTY creatable on the physical machine
      MAX_PTY=8192

      # The maximal number of virtual network interfaces that can be created on this machine
      @@vifaces_max=MAX_VIFACES

      # Initialize a physical node (set cgroups, bridge, ifb, fill the PNode cpu and memory informations, ...)
      # ==== Attributes
      # * +pnode+ The PNode object that will be filled with different informations
      # * +properties+ An hash containing specific initialization parameters (max_vifaces,)
      #
      def self.init_node(pnode,properties)
        @@vifaces_max = properties['max_vifaces'].to_i if properties['max_vifaces']
        set_cgroups()
        set_pty()
        Lib::NetTools.set_resource(@@vifaces_max)
        Lib::CPUTools.set_resource(pnode.cpu)
        Lib::MemoryTools.set_resource(pnode.memory)
        Lib::FileSystemTools.set_resource()
      end


      # Get the maximal number of vnodes that can be create on this machine
      # ==== Returns
      # Fixnum
      #
      def self.vifaces_max()
        return @@vifaces_max
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

      def self.set_pty(num=MAX_PTY)
        Lib::Shell.run("sysctl -w kernel.pty.max=#{num}")
      end
    end

  end
end
