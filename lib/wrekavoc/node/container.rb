require 'wrekavoc'
require 'thread'

module Wrekavoc
  module Node

    # Class that allow to manage all container (cgroup/lxc) associated physical and virtual resources
    class Container
      # The directory to save container configuration files
      PATH_DEFAULT_CONFIGFILE="/tmp/wrekavoc/config/"
      @@lxclock = Mutex.new

      # The virtual node this container is set for
      attr_reader :vnode
      # The object used to set up physical CPU limitations
      attr_reader  :cpuforge
      # The object used to set up network limitations
      attr_reader  :networkforges

      # Create a new Container and associate it to a virtual node
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def initialize(vnode)
        raise unless vnode.is_a?(Resource::VNode)
        raise Lib::ResourceNotFoundError, vnode.filesystem.path \
          unless File.exists?(vnode.filesystem.path)
        raise Lib::InvalidParameterError, vnode.filesystem.path \
          unless File.directory?(vnode.filesystem.path)

        unless File.exists?(PATH_DEFAULT_CONFIGFILE)
          Lib::Shell.run("mkdir -p #{PATH_DEFAULT_CONFIGFILE}")
        end

        @vnode = vnode
        @cpuforge = CPUForge.new(@vnode)
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
        Lib::Shell.run("cp -R /root/.ssh #{vnode.filesystem.path}/root/")
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
      
      # Stop all previously created containers (previous wrekavoc run, lxc, ...)
      def self.stop_all
        list = Lib::Shell::run("lxc-ls").split
        list.each do |name|
          Lib::Shell::run("lxc-stop -n #{name}")
        end
      end

      # Start all the resources associated to a virtual node (Run the virtual node)
      def start
        #stop()
        #unless @vnode.status == Resource::Status::RUNNING
          #configure()
          #@vnode.status = Resource::Status::CONFIGURING
          update()
          lxcls = Lib::Shell.run("lxc-ls")
          if (lxcls.split().include?(@vnode.name))
            @@lxclock.synchronize {
              Lib::Shell::run("lxc-start -d -n #{@vnode.name}",true)
              Lib::Shell::run("lxc-wait -n #{@vnode.name} -s RUNNING",true)
              @cpuforge.apply
              @networkforges.each_value { |netforge| netforge.apply }
            }
          else
            raise Lib::ResourceNotFoundError, @vnode.name
          end

          @vnode.vifaces.each do |viface|
            Lib::Shell::run("ethtool -K #{Lib::NetTools.get_iface_name(@vnode,viface)} gso off")
          end

          #@vnode.status = Resource::Status::RUNNING
        #end
      end

      # Stop all the resources associated to a virtual node (Shutdown the virtual node)
      def stop
        #unless @vnode.status == Resource::Status::READY
          #@vnode.status = Resource::Status::CONFIGURING
          update()
          lxcls = Lib::Shell.run("lxc-ls")
          if (lxcls.split().include?(@vnode.name))
            @@lxclock.synchronize {
              Lib::Shell::run("lxc-stop -n #{@vnode.name}",true)
              Lib::Shell::run("lxc-wait -n #{@vnode.name} -s STOPPED",true)
              @cpuforge.undo
              @networkforges.each_value { |netforge| netforge.undo }
            }
          end
          #@vnode.status = Resource::Status::READY
        #end
      end

      # Stop and Remove every physical resources that should be associated to the virtual node associated with this container (cgroups,lxc,...)
      def remove
        stop()
        #check if the lxc container name is already taken
        #@vnode.status = Resource::Status::CONFIGURING
        lxcls = Lib::Shell.run("lxc-ls")
        if (lxcls.split().include?(@vnode.name))
          Lib::Shell.run("lxc-destroy -n #{@vnode.name}")
        end
        #@vnode.status = Resource::Status::READY
      end

      # Remove and shutdown the virtual node, remove it's filesystem, ...
      def destroy
        @vnode.status = Resource::Status::CONFIGURING
        stop()
        remove()
        Lib::Shell.run("rm -R #{@vnode.filesystem.path}")
        @vnode.status = Resource::Status::READY
      end

      # Update and reconfigure a virtual node (if the was some changes in the virtual resources description)
      def reconfigure
          update()
          @cpuforge.apply
          @networkforges.each_value { |netforge| netforge.apply }
      end

      # Congigure a virtual node (set LXC config files, ...) on a physical machine
      def configure
        remove()

        #@vnode.status = Resource::Status::CONFIGURING
        @curname = "#{@vnode.name}-#{@id}"
        configfile = File.join(PATH_DEFAULT_CONFIGFILE, "config-#{@curname}")

        LXCWrapper::ConfigFile.generate(@vnode,configfile)

        Lib::Shell.run("lxc-create -f #{configfile} -n #{@vnode.name}")

        @id += 1
        #@vnode.status = Resource::Status::READY
      end
    end

  end
end
