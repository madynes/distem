require 'wrekavoc'

module Wrekavoc
  module Node

    class Admin

      PATH_CGROUP='/dev/cgroup'
      
      def self.init_node
        Lib::NetTools.set_bridge()
        set_cgroups()
      end

      def self.set_cgroups
        unless File.exists?("#{PATH_CGROUP}")
          Lib::Shell.run("mkdir #{PATH_CGROUP}")
          Lib::Shell.run("mount -t cgroup cgroup #{PATH_CGROUP}")
        end
      end
    end

  end
end
