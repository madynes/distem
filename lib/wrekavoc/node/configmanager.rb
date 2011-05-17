require 'wrekavoc'

module Wrekavoc
  module Node

    class ConfigManager
      PATH_DEFAULT_ROOTFS="/tmp/rootfs/"

      attr_reader :pnode

      def initialize
        @pnode = Wrekavoc::Resource::PNode.new(Lib::NetTools.get_default_addr())
        @vplatform = Wrekavoc::Resource::VPlatform.new
        @containers = {}
        Container.stop_all()
      end

      def get_vnode(name)
        return @vplatform.get_vnode(name)
      end
      
      def get_container(name)
        return (@containers.has_key?(name) ? @containers[name] : nil)
      end

      def get_vnodes_list()
        ret = ""
        @vplatform.vnodes.each_value do |vnode|
          ret += "\t#{vnode.name} (image:#{vnode.image})\n\t\tIfaces:\n"
          vnode.vifaces.each do |viface|
            ret += "\t\t\t#{viface.name} : #{viface.address.to_string}\n"
          end
        end
        return ret
      end

      # >>> TODO: Add the ability to modify a vnode      
      def vnode_add(vnode)
        raise "VNode already exists" if @vplatform.vnodes.has_key?(vnode.name)
        # >>> TODO: Check if the file is correct

        rootfsfile = Lib::FileManager.download(vnode.image)
        rootfspath = File.join(PATH_DEFAULT_ROOTFS,vnode.name)

        rootfspath = Lib::FileManager.extract(rootfsfile,rootfspath)

        @vplatform.add_vnode(vnode)
        @containers[vnode.name] = Node::Container.new(vnode,rootfspath)
      end

      def vnode_configure(vnodename)
        raise "VNode '#{vnodename}' not found" unless @vplatform.vnodes.has_key?(vnodename)
        @containers[vnodename].configure()
      end

      def vnode_start(vnodename)
        raise "VNode '#{vnodename}' not found" unless @vplatform.vnodes.has_key?(vnodename)
        @containers[vnodename].start()
      end

      def vnode_stop(vnodename)
        raise "VNode '#{vnodename}' not found" unless @vplatform.vnodes.has_key?(vnodename)
        @containers[vnodename].stop()
      end

      def vnode_destroy(vnodename)
        @vplatform.destroy_vnode(vnode)
        @containers[vnodename].destroy if @containers[vnodename]
        @containers[vnodename] = nil
      end

      def vroute_add(vroute)
        @vplatform.vnodes.each_value do |vnode|
        end

        @vroutes << vroute
      end

    end

  end
end
