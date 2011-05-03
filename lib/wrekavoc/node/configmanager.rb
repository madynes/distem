require 'wrekavoc'

module Wrekavoc
  module Node

    class ConfigManager
      PATH_DEFAULT_ROOTFS="/tmp/rootfs/"
      def initialize
        @vnodes = []
        @containers = {}
        #@routes
        #@tc
      end
      
      # >>> TODO: Add the ability to modify a vnode      

      def vnode_add(vnode)
        raise "VNode already exists" if @vnodes.include?(vnode)

        rootfsfile = Lib::FileManager.download(vnode.image)
        rootfspath = File.join(PATH_DEFAULT_ROOTFS,vnode.name)

        rootfspath = Lib::FileManager.extract(rootfsfile,rootfspath)

        @vnodes << vnode
        @containers[vnode] = Node::Container.new(vnode,rootfspath)
      end

      def vnode_start(vnode)
        raise "VNode '#{vnode.name}' not found" unless @vnodes.include?(vnode)
        @containers[vnode].start()
      end

      def vnode_stop(vnode)
        raise "VNode '#{vnode.name}' not found" unless @vnodes.include?(vnode)
        @containers[vnode].stop()
      end

    end

  end
end
