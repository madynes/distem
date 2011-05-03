require 'wrekavoc'

module Wrekavoc
  module Node

    class Container
      PATH_DEFAULT_CONFIGFILE="/tmp/config/"

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

        self.configure()
      end

      def start
        Lib::Shell::run("lxc-start -d -n #{@curname}")
      end

      def stop
        Lib::Shell::run("lxc-stop -n #{@curname}")
      end

      #To configure or reconfigure (if the vnode has changed)
      def configure
        @id += 1
        @curname = "#{@vnode.name}-#{@id}"
        configfile = File.join(PATH_DEFAULT_CONFIGFILE, "config-#{@curname}")
        File.open(configfile, 'w') { |f| f.puts("It works!") }
        #ContainerWrapper.perform_config(configfile,vnode)
      end
    end

  end
end
