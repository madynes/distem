require 'wrekavoc'
require 'thread'

module Wrekavoc
  module Node

    class Container
      PATH_DEFAULT_CONFIGFILE="/tmp/wrekavoc/config/"
      @@lxclock = Mutex.new

      attr_reader :vnode

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
        @curname = ""
        @configfile = ""
        @id = 0
      end
      
      def self.stop_all
        list = Lib::Shell::run("lxc-ls").split
        list.each do |name|
          Lib::Shell::run("lxc-stop -n #{name}")
        end
      end

      def start
        #stop()
        #unless @vnode.status == Resource::Status::RUNNING
          #configure()
          #@vnode.status = Resource::Status::CONFIGURING
          lxcls = Lib::Shell.run("lxc-ls")
          if (lxcls.split().include?(@vnode.name))
            @@lxclock.synchronize {
              Lib::Shell::run("lxc-start -d -n #{@vnode.name}",true)
              Lib::Shell::run("lxc-wait -n #{@vnode.name} -s RUNNING",true)
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

      def stop
        #unless @vnode.status == Resource::Status::READY
          #@vnode.status = Resource::Status::CONFIGURING
          lxcls = Lib::Shell.run("lxc-ls")
          if (lxcls.split().include?(@vnode.name))
            @@lxclock.synchronize {
              Lib::Shell::run("lxc-stop -n #{@vnode.name}",true)
              Lib::Shell::run("lxc-wait -n #{@vnode.name} -s STOPPED",true)
            }
          end
          #@vnode.status = Resource::Status::READY
        #end
      end

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

      def destroy
        @vnode.status = Resource::Status::CONFIGURING
        stop()
        remove()
        Lib::Shell.run("rm -R #{@vnode.filesystem.path}")
        @vnode.status = Resource::Status::READY
      end

      #To configure or reconfigure (if the vnode has changed)
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
