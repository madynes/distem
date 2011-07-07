require 'wrekavoc'

module Wrekavoc
  module Node

    class ConfigManager
      PATH_DEFAULT_ROOTFS="/tmp/wrekavoc/rootfs/"

      attr_reader :pnode, :vplatform
      attr_writer :pnode

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

      # >>> TODO: Add the ability to modify a vnode      
      def vnode_add(vnode)
        @vplatform.add_vnode(vnode)

        rootfsfile = Lib::FileManager.download(vnode.filesystem.image)
        rootfspath = File.join(PATH_DEFAULT_ROOTFS,vnode.name)

        rootfspath = Lib::FileManager.extract(rootfsfile,rootfspath)
        vnode.filesystem.path = rootfspath

        @containers[vnode.name] = Node::Container.new(vnode)
      end

      def vnode_remove(vnode)
        raise unless vnode.is_a?(Resource::VNode)
        @vplatform.remove_vnode(vnode)
        @containers[vnode.name].destroy if @containers[vnode.name]
        @containers.delete(vnode.name)
      end

      #def vnode_configure(vnodename)
      #  vnode = @vplatform.get_vnode(vnodename)
      #  raise Lib::ResourceNotFoundError, vnodename unless vnode
      #  @containers[vnodename].configure()
      #end

      def vnode_start(vnodename)
        vnode = @vplatform.get_vnode(vnodename)
        raise Lib::ResourceNotFoundError, vnodename unless vnode
        @containers[vnodename].configure()
        @containers[vnodename].start()
        vnode.vifaces.each do |viface|
          if viface.limitation? and !viface.limited?
            viface_configure(viface)
          end
        end
      end

      def viface_flush(viface)
        raise Lib::ResourceNotFoundError, viface unless viface

        if viface.limited?
          NetworkLimitation.undo(viface)
          viface.limited = false
        end
      end

      def viface_configure(viface)
        raise Lib::ResourceNotFoundError, viface unless viface
        raise Lib::AlreadyExistingResourceError, 'limitation' if viface.limited?

        NetworkLimitation.apply(viface)
        viface.limited = true
      end

      def vnode_stop(vnodename)
        vnode = @vplatform.get_vnode(vnodename)
        raise Lib::ResourceNotFoundError, vnodename unless vnode
        vnode.vifaces.each do |viface|
          unless viface.limited?
            NetworkLimitation.undo(viface)
            viface.limited = false
          end
        end
        @containers[vnodename].stop()
      end

      def viface_add(viface)
        raise Lib::ShellError, 'Maximum ifaces numbre reached' if viface.id >= Admin::MAX_IFACES
        Lib::Shell.run("ip link set dev ifb#{viface.id} up")
      end

      def viface_remove(viface)
        viface_detach(viface)
      end

      def viface_detach(viface)
        NetworkLimitation.undo(viface)
        viface.detach()
      end

      def vnetwork_add(vnetwork)
        @vplatform.add_vnetwork(vnetwork)
      end

      def vnetwork_remove(vnetwork)
        vnodes = vnetwork.vnodes.clone
        @vplatform.remove_vnetwork(vnetwork)
        #vnodes.each_pair do |vnode,viface|
        #  vnode_configure(vnode)
        #end
      end

      def vroute_add(vroute)
        @vplatform.add_vroute(vroute)
      end

      def vroute_remove(vroute)
        @vplatform.remove_vroute(vroute)
      end

      def destroy(resource)
        if resource.is_a?(Resource::VNode)
          vnode_remove(resource)
        elsif resource.is_a?(Resource::VNetwork)
          vnetwork_remove(resource)
        elsif resource.is_a?(Resource::VRoute)
          vroute_remove(resource)
        end
      end
    end

  end
end
