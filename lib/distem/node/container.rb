require 'distem'
require 'thread'

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
        raise Lib::UninitializedResourceError, "vfilesysem/image" unless vnode.filesystem

        @vnode = vnode

        @fsforge = FileSystemForge.new(@vnode)
        raise Lib::ResourceNotFoundError, @vnode.filesystem.path if \
          !File.exists?(@vnode.filesystem.path) and
          !File.exists?(@vnode.filesystem.sharedpath)
        @cpuforge = CPUForge.new(@vnode,@vnode.host.algorithms[:cpu])
        @networkforges = {}
        @vnode.vifaces.each do |viface|
          @networkforges[viface] = NetworkForge.new(viface)
        end
        @curname = ""
        @configfile = ""
        @id = 0

        setup()
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
        unless File.exists?(sshpath)
          Lib::Shell.run("mkdir -p #{sshpath}")
        end

        # Copying every private keys if not already existing
        Daemon::Admin.ssh_keys_priv.each do |keyfile|
          keypath=File.join(sshpath,"#{SSH_KEY_PREFIX}#{File.basename(keyfile)}")
          Lib::Shell.run("cp #{keyfile} #{keypath}") unless File.exists?(keypath)
        end
        File.open(File.join(sshpath,SSH_KEY_FILENAME),'w') do |f|
          f.puts @vnode.sshkey['private']
        end if @vnode.sshkey and @vnode.sshkey['private']

        # Copying every public keys if not already existing
        Daemon::Admin.ssh_keys_pub.each do |keyfile|
          keypath=File.join(sshpath,"#{SSH_KEY_PREFIX}#{File.basename(keyfile)}")
          Lib::Shell.run("cp #{keyfile} #{keypath}") unless File.exists?(keypath)
        end
        File.open(File.join(sshpath,"#{SSH_KEY_FILENAME}.pub"),'w') do |f|
          f.puts @vnode.sshkey['public']
        end if @vnode.sshkey and @vnode.sshkey['public']

        # Copying authorized_keys file of the host
        hostauthfile = File.join(Daemon::Admin::PATH_SSH,'authorized_keys')
        authfile = File.join(sshpath,'authorized_keys')
        if File.exists?(authfile)
          authkeys = IO.readlines(authfile).collect{|v| v.chomp}
          hostauthkeys = IO.readlines(hostauthfile).collect{|v| v.chomp}
          hostauthkeys.each do |key|
            File.open(authfile,'a') { |f| f.puts key } unless \
              authkeys.include?(key)
          end
        else
          Lib::Shell.run("cp -f #{hostauthfile} #{authfile}") if File.exists?(hostauthfile)
        end

        # Adding public keys to SSH authorized_keys file
        pubkeys = Daemon::Admin.ssh_keys_pub.collect{ |v| IO.read(v).chomp }
        pubkeys << @vnode.sshkey['public'] if @vnode.sshkey and @vnode.sshkey['public']
        if File.exists?(authfile)
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
            Lib::Shell::run("ethtool -K #{Lib::NetTools.get_iface_name(@vnode,viface)} gso off")
          end
          @cpuforge.apply
          @networkforges.each_value { |netforge| netforge.apply }
        end
      end

      # Stop all the resources associated to a virtual node (Shutdown the virtual node)
      def stop
        @@contsem.synchronize do
          @cpuforge.undo
          @networkforges.each_value { |netforge| netforge.undo }
          LXCWrapper::Command.stop(@vnode.name)
        end
      end

      # Stop and Remove every physical resources that should be associated to the virtual node associated with this container (cgroups,lxc,...)
      def remove
        LXCWrapper::Command.destroy(@vnode.name,true)
        Lib::Shell.run("rm -R #{@vnode.filesystem.path}") unless \
          @vnode.filesystem.shared
      end

      # Remove and shutdown the virtual node, remove it's filesystem, ...
      def destroy
        stop()
        remove()
      end

      # Update and reconfigure a virtual node (if the was some changes in the virtual resources description)
      def reconfigure
          @cpuforge.apply
          @networkforges.each_value { |netforge| netforge.apply }
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

          Lib::Shell.run("mkdir -p #{etcpath}") unless File.exists?(etcpath)

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
            Lib::Shell.run("mkdir -p #{etcpath}") unless File.exists?(etcpath)
            filename = File.join(etcpath,'rc.local')
            cmd = '. /etc/rc.local-`hostname`'
            ret = Lib::Shell.run("grep '#{cmd}' #{filename}; true",true)
            if ret.empty?
              File.open(filename,'w') do |f|
                f.puts("#!/bin/sh -ex\n")
                f.puts(cmd)
                f.puts("exit 0")
              end
              File.chmod(0755,filename)
            end
          }

          if @vnode.filesystem.shared
            @@filelock.synchronize { block.call }
          else
            block.call
          end

          # Node specific rc.local
          filename = File.join(etcpath,"rc.local-#{@vnode.name}")
          File.open(filename, "w") do |f|
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
          end
          File.chmod(0755,filename)

          LXCWrapper::Command.create(@vnode.name,configfile)

          @id += 1
        end
      end
    end

  end
end
