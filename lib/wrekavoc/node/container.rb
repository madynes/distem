require 'wrekavoc'

module Wrekavoc
  module Node

    class Container
      PATH_DEFAULT_CONFIGFILE="/tmp/config/"

      STATUS_STOP=0
      STATUS_RUN=1

      attr_reader :rootfspath

      def initialize(vnode,rootfspath)
        raise unless vnode.is_a?(Resource::VNode)
        raise "RootFS directory '#{rootfspath}' not found" \
          unless File.exists?(rootfspath)
        raise "Invalid RootFS directory '#{rootfspath}'" \
          unless File.directory?(rootfspath)

        unless File.exists?(PATH_DEFAULT_CONFIGFILE)
          Lib::Shell.run("mkdir -p #{PATH_DEFAULT_CONFIGFILE}")
        end

        @vnode = vnode
        @rootfspath = rootfspath
        @curname = ""
        @configfile = ""
        @id = 0
        @status = STATUS_STOP

        self.configure()
      end

      def start
        Lib::Shell::run("lxc-start -d -n #{@vnode.name}") if @status == STATUS_STOP
      end

      def stop
        Lib::Shell::run("lxc-stop -n #{@vnode.name}") if @status == STATUS_RUN
      end

      #To configure or reconfigure (if the vnode has changed)
      def configure
        stop()
        Lib::Shell.run("lxc-destroy -n #{@vnode.name}") unless @curname.empty?

        @curname = "#{@vnode.name}-#{@id}"
        configfile = File.join(PATH_DEFAULT_CONFIGFILE, "config-#{@curname}")

        LXCWrapper::ConfigFile.generate(@vnode,configfile,@rootfspath)

        Lib::Shell.run("lxc-create -f #{configfile} -n #{@vnode.name}")

        @id += 1
      end
    end

  end
end
