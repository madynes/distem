require 'wrekavoc'

module Wrekavoc
  module Node

    class ConfigManager
      PATH_DEFAULT_ROOTFS="/tmp/rootfs/"

      attr_reader :pnode

      def initialize
        @pnode = Wrekavoc::Resource::PNode.new(Lib::NetTools.get_default_addr())
        @vnodes = {}
        @containers = {}
        #@routes
        #@tc
      end

      def get_vnode(name)
        return (@vnodes.has_key?(name) ? @vnodes[name] : nil)
      end
      
      def get_container(name)
        return (@containers.has_key?(name) ? @containers[name] : nil)
      end

      def include?(name)
        return @vnodes[name]
      end

      # >>> TODO: Add the ability to modify a vnode      
      def vnode_add(vnode)
        raise "VNode already exists" if @vnodes.has_key?(vnode.name)
        # >>> TODO: Check if the file is correct

        rootfsfile = Lib::FileManager.download(vnode.image)
        rootfspath = File.join(PATH_DEFAULT_ROOTFS,vnode.name)

        rootfspath = Lib::FileManager.extract(rootfsfile,rootfspath)

        @vnodes[vnode.name] = vnode
        @containers[vnode.name] = Node::Container.new(vnode,rootfspath)
      end

      def vnode_configure(vnodename)
        raise "VNode '#{vnodename}' not found" unless @vnodes.has_key?(vnodename)
        @containers[vnodename].configure()
      end

      def vnode_start(vnodename)
        raise "VNode '#{vnodename}' not found" unless @vnodes.has_key?(vnodename)
        @containers[vnodename].start()
      end

      def vnode_stop(vnodename)
        raise "VNode '#{vnodename}' not found" unless @vnodes.has_key?(vnodename)
        @containers[vnodename].stop()
      end

      def vnode_destroy(vnodename)
        @vnodes[vnodename] = nil
        @containers[vnodename].destroy if @containers[vnodename]
        @containers[vnodename] = nil
      end

    end

  end
end
