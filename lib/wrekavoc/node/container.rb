require 'wrekavoc'

module Wrekavoc
  module Node

    class Container
      PATH_DEFAULT_CONFIGFILE="/tmp/config/"

      attr_reader :rootfspath

      def initialize(vnode,rootfspath)
        raise unless vnode.is_a?(Resource::VNode)
        raise Lib::ResourceNotFoundError, rootfspath \
          unless File.exists?(rootfspath)
        raise Lib::InvalidParameterError, rootfspath \
          unless File.directory?(rootfspath)

        unless File.exists?(PATH_DEFAULT_CONFIGFILE)
          Lib::Shell.run("mkdir -p #{PATH_DEFAULT_CONFIGFILE}")
        end

        @vnode = vnode
        @rootfspath = rootfspath
        @curname = ""
        @configfile = ""
        @id = 0

        configure()
      end
      
      def self.stop_all
        list = Lib::Shell::run("lxc-ls").split
        list.each do |name|
          Lib::Shell::run("lxc-stop -n #{name}")
        end
      end

      def start
        stop()
        @vnode.status = Resource::VNode::Status::STARTING
        Lib::Shell::run("lxc-start -d -n #{@vnode.name}")
        Lib::Shell::run("lxc-wait -n #{@vnode.name} -s RUNNING")
        @vnode.vifaces.each do |viface|
          Lib::Shell::run("ethtool -K #{Lib::NetTools.get_iface_name(@vnode,viface)} gso off")
        end
        @vnode.status = Resource::VNode::Status::RUNNING
      end

      def stop
        Lib::Shell::run("lxc-stop -n #{@vnode.name}")
        @vnode.status = Resource::VNode::Status::STOPING
        Lib::Shell::run("lxc-wait -n #{@vnode.name} -s STOPPED")
        @vnode.status = Resource::VNode::Status::STOPPED
      end

      def destroy
        stop()

        #check if the lxc container name is already taken
        lxcls = Lib::Shell.run("lxc-ls")
        if (lxcls.split().include?(@vnode.name))
          Lib::Shell.run("lxc-destroy -n #{@vnode.name}")
        end
      end

      #To configure or reconfigure (if the vnode has changed)
      def configure
        destroy()

        @vnode.status = Resource::VNode::Status::CONFIGURING
        @curname = "#{@vnode.name}-#{@id}"
        configfile = File.join(PATH_DEFAULT_CONFIGFILE, "config-#{@curname}")

        LXCWrapper::ConfigFile.generate(@vnode,configfile,@rootfspath)

        Lib::Shell.run("lxc-create -f #{configfile} -n #{@vnode.name}")

        @id += 1
        @vnode.status = Resource::VNode::Status::STOPPED
      end
    end

  end
end
