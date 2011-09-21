require 'distem'
require 'thread'

module Distem
module Node

  # Class that allow to manage all container (cgroup/lxc) associated physical and virtual resources
  class Container
    # The maximum simultaneous actions (start,stop)
    MAX_SIMULTANEOUS_ACTIONS = 32

    # Clean only one time
    @@cleanlock = Mutex.new
    # Was the system cleaned
    @@cleaned = false
    # Only write on common files once at the same time
    @@filelock = Mutex.new
    # Max number of simultaneous action
    @@contsem = Lib::Semaphore.new(MAX_SIMULTANEOUS_ACTIONS)

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
    def initialize(vnode,cpu_algorithm=nil)
      raise unless vnode.is_a?(Resource::VNode)

      @vnode = vnode
      @cpuforge = CPUForge.new(@vnode,cpu_algorithm)
      @fsforge = FileSystemForge.new(@vnode)
      raise Lib::ResourceNotFoundError, @vnode.filesystem.path \
        unless File.exists?(@vnode.filesystem.path)
      raise Lib::InvalidParameterError, @vnode.filesystem.path \
        unless File.directory?(@vnode.filesystem.path)
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
      rootfspath = File.join(rootfspath,'root','.ssh')

      unless File.exists?(rootfspath)
        Lib::Shell.run("mkdir -p #{rootfspath}")
        Lib::Shell.run("cp -f #{File.join(ENV['HOME'],'.ssh')}/* #{rootfspath}/")
      end
    end

      # Create new resource limitation objects if the virtual node resource has changed
      def update()
        iftocreate = @vnode.vifaces - @networkforges.keys
        iftocreate.each do |viface|
          @networkforges[viface] = NetworkForge.new(viface)
        end
        iftoremove = @networkforges.keys - @vnode.vifaces
        iftoremove.each do |viface|
          @networkforges[viface].undo
          @networkforges.delete(viface)
        end
      end
      
      # Clean every previously created containers (previous distem run, lxc, ...)
      def self.clean
        unless @@cleaned
          if (@@cleanlock.locked?)
            @@cleanlock.synchronize{}
          else
            @@cleanlock.synchronize {
              LXCWrapper::Command.stopall()
              LXCWrapper::Command.destroyall()
            }
          end
          @@cleaned = true
        end
      end

      # Start all the resources associated to a virtual node (Run the virtual node)
      def start
        update()

        @@contsem.synchronize do
          LXCWrapper::Command.start(@vnode.name)
          @cpuforge.apply
          @networkforges.each_value { |netforge| netforge.apply }
          @vnode.vifaces.each do |viface|
            Lib::Shell::run("ethtool -K #{Lib::NetTools.get_iface_name(@vnode,viface)} gso off")
          end
        end
      end

      # Stop all the resources associated to a virtual node (Shutdown the virtual node)
      def stop
        update()
        @@contsem.synchronize do
          LXCWrapper::Command.stop(@vnode.name)
          @cpuforge.undo
          @networkforges.each_value { |netforge| netforge.undo }
        end
      end

      # Stop and Remove every physical resources that should be associated to the virtual node associated with this container (cgroups,lxc,...)
      def remove
        LXCWrapper::Command.destroy(@vnode.name,true)
      end

      # Remove and shutdown the virtual node, remove it's filesystem, ...
      def destroy
        stop()
        remove()
        # >>>TODO: remove created files in shared filesystem
        Lib::Shell.run("rm -R #{@vnode.filesystem.path}")
      end

      # Update and reconfigure a virtual node (if the was some changes in the virtual resources description)
      def reconfigure
          update()
          @cpuforge.apply
          @networkforges.each_value { |netforge| netforge.apply }
      end

      # Congigure a virtual node (set LXC config files, ...) on a physical machine
      def configure
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
          filename = File.join(etcpath,'rc.local')
          cmd = '. /etc/rc.local-`hostname`'
          ret = Lib::Shell.run("grep '#{cmd}' #{filename}; true",true)
          if ret.empty?
            File.open(filename,'w') do |f|
              f.puts("#!/bin/sh -e\n")
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
          f.puts("#!/bin/sh -e\n")
          f.puts("echo 1 > /proc/sys/net/ipv4/ip_forward") if @vnode.gateway?
          @vnode.vifaces.each do |viface|
            f.puts("ip route flush dev #{viface.name}")
            if viface.vnetwork
              f.puts("ifconfig #{viface.name} #{viface.address.address.to_s} netmask #{viface.address.netmask.to_s}")
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
