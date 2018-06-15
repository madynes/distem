#require 'distem'

module Distem
  module Node

    # Class that allow to set up a physical node resources (init cgroups, tc, ...)
    class Admin
      # The directory used to store distem logs
      PATH_DISTEM_LOGS='/var/log/distem/'
      # The directory used to store temporary files
      PATH_DISTEMTMP='/tmp/distem/'
      # The default maximum number of virual network interfaces (used with ifb)
      MAX_VIFACES=64
      # The default maximum number of PTY creatable on the physical machine
      MAX_PTY=8192

      # The maximal number of virtual network interfaces that can be created on this machine
      @@vifaces_max=MAX_VIFACES

      #The path to cgroup1 for this pnode (i.e /sys/fs/cgroup)
      @cgroup1_path=nil
      #The path to cgroup2 for this pnode (i.e /sys/fs/cgroup/unified)
      @cgroup2_path=nil

      # Initialize a physical node (set cgroups, bridge, ifb, fill the PNode cpu and memory informations, ...)
      # ==== Attributes
      # * +pnode+ The PNode object that will be filled with different informations
      # * +properties+ An hash containing specific initialization parameters (max_vifaces,)
      #
      def self.init_node(pnode,properties)
        @@vifaces_max = properties['max_vifaces'].to_i if properties['max_vifaces']
        set_cgroups()
        set_pty()
        Lib::NetTools.set_resource(@@vifaces_max,properties['set_bridge'])
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
      def self.quit_node()
        Lib::NetTools.unset_ifb()
        unset_cgroups()
        Lib::Shell.run("rm -R #{PATH_DISTEMTMP}") if File.exist?(PATH_DISTEMTMP)
      end

      # Set paths to the cgroups fs, mount them otherwise
      def self.set_cgroups
          #We assume cgroup1 is always mounted somewhere on a tmpfs: should work on most systems
          @cgroup1_path = Lib::Shell.run("mount | grep cgroup |  grep tmpfs | cut -d ' ' -f3").lines.first.chomp
          #
          @cgroup2_path = Lib::Shell.run("mount | grep cgroup2 | cut -d ' ' -f3").lines.first.chomp
          if @cgroup2_path == ''
            @cgroup2_path = '/sys/fs/cgroup/unified'
            Lib::Shell.run("mkdir -p #{@cgroup2_path}")
            Lib::Shell.run("mount -t cgroup2 rw,nosuid,nodev,noexec,relatime #{@cgroup2_path}")
          end
          #Get the controllers available on the v2 hierarchy and activate them on the tree
          #LXC does not do the following by itself, so we have to do it manually
          #https://github.com/lxc/lxc/issues/2379
          controllers = Lib::Shell.run("sed -r 's/([^ ]+)/+&/g' #{@cgroup2_path}/cgroup.controllers"\
                                       "> #{@cgroup2_path}/cgroup.subtree_control")
      end

      # Deactivate limits
      def self.unset_cgroups
          Lib::Shell.run("find #{@cgroup1_path}/*/lxc/* -depth -type d -print -exec rmdir {} \\;")
          Lib::Shell.run("find #{@cgroup2_path}/lxc/* -depth -type d -print -exec rmdir {} \\;")
      end

      def self.set_pty(num=MAX_PTY)
        Lib::Shell.run("sysctl -w kernel.pty.max=#{num}")
      end
    end

  end
end
