#require 'distem'
require 'thread'
require 'fileutils'

module Distem
  module Node

    # Class that allow to manage all container (cgroup/lxc) associated physical and virtual resources
    class Container
      # The maximum simultaneous actions (start,stop)
      MAX_SIMULTANEOUS_ACTIONS = 32
      MAX_SIMULTANEOUS_CONFIG = 32
      # The prefix to set to the SSH key whick are copied on the virtual nodes
      SSH_KEY_PREFIX = ''
      # The default file to save virtual node specific ssh key pair (see Distem::Resource::VNode::sshkey)
      SSH_KEY_FILENAME = 'identity'

      # Clean only one time
      @@cleanlock = Mutex.new
      # Was the system cleaned
      @@cleaned = false
      # Only write on common files once at the same time
      @@filelock = Mutex.new
      # Max number of simultaneous action
      @@contsem = Lib::Semaphore.new(MAX_SIMULTANEOUS_ACTIONS)
      # Max number of simultaneous config action
      @@confsem = Lib::Semaphore.new(MAX_SIMULTANEOUS_CONFIG)

      # The virtual node this container is set for
      attr_reader :vnode
      # The object used to set up physical CPU limitations
      attr_reader  :cpuforge
      # The object used to set up physical filesystem
      attr_reader  :fsforge
      # The object used to set up network limitations
      attr_reader  :networkforges

      # Create a new Container and associate it to a virtual node
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def initialize(vnode)
        raise unless vnode.is_a?(Resource::VNode)
        raise Lib::UninitializedResourceError, "vfilesystem/image" unless vnode.filesystem

        @vnode = vnode
        @fsforge = FileSystemForge.new(@vnode)
        raise Lib::ResourceNotFoundError, @vnode.filesystem.path if \
          !File.exist?(@vnode.filesystem.path) and
          !File.exist?(@vnode.filesystem.sharedpath)
        @cpuforge = CPUForge.new(@vnode,@vnode.host.algorithms[:cpu])
        @networkforges = {}
        @vnode.vifaces.each do |viface|
          @networkforges[viface] = NetworkForge.new(viface)
        end
        @curname = ""
        @configfile = ""
        @id = 0
        setup()
        @stopped = false
      end

      # Setup the virtual node container (copy ssh keys, ...)
      #
      def setup()
        rootfspath = nil
        if @vnode.filesystem.shared
          rootfspath = @vnode.filesystem.sharedpath
        else
          rootfspath = @vnode.filesystem.path
        end
        sshpath = File.join(rootfspath,'root','.ssh')

        # Creating SSH directory
        unless File.exist?(sshpath)
          Lib::Shell.run("mkdir -p #{sshpath}")
        end

        # Copying every private keys if not already existing
        Daemon::Admin.ssh_keys_priv.each do |keyfile|
          keypath=File.join(sshpath,"#{SSH_KEY_PREFIX}#{File.basename(keyfile)}")
          Lib::Shell.run("cp #{keyfile} #{keypath}") unless File.exist?(keypath)
        end
        File.open(File.join(sshpath,SSH_KEY_FILENAME),'w') do |f|
          f.puts @vnode.sshkey['private']
        end if @vnode.sshkey and @vnode.sshkey['private']

        # Copying every public keys if not already existing
        Daemon::Admin.ssh_keys_pub.each do |keyfile|
          keypath=File.join(sshpath,"#{SSH_KEY_PREFIX}#{File.basename(keyfile)}")
          Lib::Shell.run("cp #{keyfile} #{keypath}") unless File.exist?(keypath)
        end
        File.open(File.join(sshpath,"#{SSH_KEY_FILENAME}.pub"),'w') do |f|
          f.puts @vnode.sshkey['public']
        end if @vnode.sshkey and @vnode.sshkey['public']

        # Copying authorized_keys file of the host
        hostauthfile = File.join(Daemon::Admin::PATH_SSH,'authorized_keys')
        authfile = File.join(sshpath,'authorized_keys')
        if File.exist?(authfile)
          authkeys = IO.readlines(authfile).collect{|v| v.chomp}
          hostauthkeys = IO.readlines(hostauthfile).collect{|v| v.chomp}
          hostauthkeys.each do |key|
            File.open(authfile,'a') { |f| f.puts key } unless \
              authkeys.include?(key)
          end
        else
          Lib::Shell.run("cp -f #{hostauthfile} #{authfile}") if File.exist?(hostauthfile)
        end

        # Adding public keys to SSH authorized_keys file
        pubkeys = Daemon::Admin.ssh_keys_pub.collect{ |v| IO.read(v).chomp }
        pubkeys << @vnode.sshkey['public'] if @vnode.sshkey and @vnode.sshkey['public']
        if File.exist?(authfile)
          authkeys = IO.readlines(authfile).collect{|v| v.chomp} unless authkeys
          pubkeys.each do |key|
            File.open(authfile,'a') { |f| f.puts key } unless \
              authkeys.include?(key)
          end
        else
          pubkeys.each do |key|
            File.open(authfile,'a') { |f| f.puts key }
          end
        end
      end

      # Clean every previously created containers (previous distem run, lxc, ...)
      def self.clean
        unless @@cleaned
          if (@@cleanlock.locked?)
            @@cleanlock.synchronize{}
          else
            @@cleanlock.synchronize {
              LXCWrapper::Command.clean()
            }
          end
          @@cleaned = true
        end
      end

      # Start all the resources associated to a virtual node (Run the virtual node)
      def start
        raise @vnode.name if @vnode.status == Resource::Status::RUNNING
        @@contsem.synchronize do
          LXCWrapper::Command.start(@vnode.name)
          @vnode.vifaces.each do |viface|
            Lib::Shell::run("ethtool -K #{Lib::NetTools.get_iface_name(@vnode,viface)} gso off || true")
            Lib::Shell::run("ethtool -K #{Lib::NetTools.get_iface_name(@vnode,viface)} tso off || true")
          end
          @cpuforge.apply
          @networkforges.each_value { |netforge| netforge.apply }
        end
        if @vnode.filesystem.disk_throttling
          # On jessie, this does not return a correct value ...
          #major = File.stat(@vnode.filesystem.disk_throttling['device']).dev_major
          major = `stat --printf %t #{@vnode.filesystem.disk_throttling['device']}`
          cgroup_path = File.join(Distem::Node::Admin::PATH_CGROUP, 'lxc', @vnode.name)
          # In the description, read and write limits are supposed to be specified in bytes
          if @vnode.filesystem.disk_throttling['read_limit']
            limit = @vnode.filesystem.disk_throttling['read_limit'].to_i
            Lib::Shell::run("echo \"#{major}:0 #{limit}\" > #{cgroup_path}/blkio.throttle.read_bps_device")
          end
          if @vnode.filesystem.disk_throttling['write_limit']
            limit = @vnode.filesystem.disk_throttling['write_limit'].to_i
            Lib::Shell::run("echo \"#{major}:0 #{limit}\" > #{cgroup_path}/blkio.throttle.write_bps_device")
          end
        end
        @stopped = false
      end

      # Stop all the resources associated to a virtual node (Shutdown the virtual node)
      def stop
        if @vnode.filesystem.disk_throttling
          cgroup_path = File.join(Distem::Node::Admin::PATH_CGROUP, 'lxc', @vnode.name)
          Lib::Shell::run("echo -n > #{cgroup_path}/blkio.throttle.read_bps_device") if @vnode.filesystem.disk_throttling['read_limit']
          Lib::Shell::run("echo -n > #{cgroup_path}/blkio.throttle.write_bps_device") if @vnode.filesystem.disk_throttling['write_limit']
        end
        @@contsem.synchronize do
          @cpuforge.undo
          @networkforges.each_value { |netforge| netforge.undo }
          LXCWrapper::Command.stop(@vnode.name)
        end
        @stopped = true
      end

      # Stop and Remove every physical resources that should be associated to the virtual node associated with this container (cgroups,lxc,...)
      def remove
        LXCWrapper::Command.destroy(@vnode.name,true)
        if !@vnode.filesystem.shared && @vnode.filesystem.cow
          # The subvolume deletion is performed automatically by LXC in the Jessie version.
          if File.exist?(@vnode.filesystem.path)
            Lib::Shell.run("btrfs subvolume delete #{@vnode.filesystem.path}")
          end
        end
      end

      # Remove and shutdown the virtual node, remove it's filesystem, ...
      def destroy
        stop() if !@stopped
        remove()
      end

      def freeze
        LXCWrapper::Command.freeze(@vnode.name)
      end

      def unfreeze
        LXCWrapper::Command.unfreeze(@vnode.name)
      end

      # Update and reconfigure a virtual node (if the was some changes in the virtual resources description)
      def reconfigure
          @cpuforge.apply
          @networkforges.each_value { |netforge| netforge.apply }
      end

      def set_global_etchosts(data)
        rootfspath = @vnode.filesystem.shared ? @vnode.filesystem.sharedpath : @vnode.filesystem.path
        etcpath = File.join(rootfspath,'etc')
        File.open(File.join(etcpath,'hosts'),'w') {|f|
          f.write(data + "\n")
        }
      end

      def set_global_arptable(data, file)
        rootfspath = @vnode.filesystem.shared ? @vnode.filesystem.sharedpath : @vnode.filesystem.path
        path = File.join(rootfspath, file)
        File.open(path,'w') {|f|
          f.write(data + "\n")
        }
      end

      # Congigure a virtual node (set LXC config files, ...) on a physical machine
      def configure
        @@confsem.synchronize do
          rootfspath = nil
          if @vnode.filesystem.shared
            rootfspath = @vnode.filesystem.sharedpath
          else
            rootfspath = @vnode.filesystem.path
          end

          @curname = "#{@vnode.name}-#{@id}"

          # Generate lxc configfile
          configfile = File.join(FileSystemForge::PATH_DEFAULT_CONFIGFILE, "config-#{@curname}")
          LXCWrapper::ConfigFile.generate(@vnode,configfile)

          etcpath = File.join(rootfspath,'etc')

          # Make hostname local
          unless @vnode.filesystem.shared
            File.open(File.join(etcpath,'hosts'),'a') do |f|
              f.puts("127.0.0.1\t#{@vnode.name}")
              f.puts("::1\t#{@vnode.name}")
            end
          end

          block = Proc.new {
            # Make address local
            @vnode.vifaces.each do |viface|
              if viface.vnetwork
                File.open(File.join(etcpath,'hosts'),'a') do |f|
                  f.puts("#{viface.address.address.to_s}\t#{@vnode.name}")
                end
              end
            end

            # Load config in rc.local
            filename = File.join(etcpath,'rc.local')
            cmd = '. /etc/rc.local-`hostname`'
            ret = Lib::Shell.run("grep '#{cmd}' #{filename}; true",true)
            if ret.empty?
              File.open(filename,File::WRONLY|File::TRUNC|File::CREAT, 0755) { |f|
                f.puts("#!/bin/sh -ex\n")
                f.puts(cmd)
                f.puts("exit 0")
              }
            end
            # Make the file executable even if it was already existing. rc.local is 644 by default.
            FileUtils.chmod(0755, filename)
          }

          if @vnode.filesystem.shared
            @@filelock.synchronize { block.call }
          else
            block.call
          end
          # Node specific rc.local
          filename = File.join(etcpath,"rc.local-#{@vnode.name}")
          File.open(filename,File::WRONLY|File::TRUNC|File::CREAT, 0755) { |f|
            f.puts("#!/bin/sh -ex\n")
            f.puts("echo 1 > /proc/sys/net/ipv4/ip_forward") if @vnode.gateway?
            @vnode.vifaces.each do |viface|
              if viface.vnetwork
                addr = viface.address
                f.puts("ifconfig #{viface.name} #{addr.address.to_s} netmask #{addr.netmask.to_s} broadcast #{addr.broadcast.to_s}")
                f.puts("ip route flush dev #{viface.name}")
                f.puts("ip route add #{viface.vnetwork.address.to_string} dev #{viface.name}")
                #compute all routes
                viface.vnetwork.vroutes.each_value do |vroute|
                  f.puts("ip route add #{vroute.dstnet.address.to_string} via #{vroute.gw.address.to_s} dev #{viface.name}") unless vroute.gw.address.to_s == viface.address.to_s
                end
              end
              f.puts("#iptables -t nat -A POSTROUTING -o #{viface.name} -j MASQUERADE") if vnode.gateway?
            end
            f.puts("exit 0")
          }
          LXCWrapper::Command.create(@vnode.name,configfile)

          @id += 1
        end
      end
    end
  end
end
