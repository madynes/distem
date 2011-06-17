require 'wrekavoc'

module Wrekavoc
  module Node

    class ConfigManager
      PATH_DEFAULT_ROOTFS="/tmp/rootfs/"

      attr_reader :pnode, :vplatform
      attr_writer :pnode

      def initialize
        @pnode = Wrekavoc::Resource::PNode.new(Lib::NetTools.get_default_addr())
        @vplatform = Wrekavoc::Resource::VPlatform.new
        @vnetlimit = Wrekavoc::Limitation::Network::Manager.new
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
        ret = {}
        @vplatform.vnodes.each_value do |vnode|
          ret[vnode.name] = vnode.to_hash
        end
        return ret
      end

      # >>> TODO: Add the ability to modify a vnode      
      def vnode_add(vnode)
        @vplatform.add_vnode(vnode)

        rootfsfile = Lib::FileManager.download(vnode.image)
        rootfspath = File.join(PATH_DEFAULT_ROOTFS,vnode.name)

        rootfspath = Lib::FileManager.extract(rootfsfile,rootfspath)

        @containers[vnode.name] = Node::Container.new(vnode,rootfspath)
      end

      def viface_add(viface)
        raise 'Maximum ifaces numbre reached' if viface.id >= Admin::MAX_IFACES
        Lib::Shell.run("ip link set dev ifb#{viface.id} up")
      end

      def vnetwork_add(vnetwork)
        @vplatform.add_vnetwork(vnetwork)
      end

      def vnode_configure(vnodename)
        raise Lib::ResourceNotFoundError, vnodename \
           unless @vplatform.get_vnode(vnodename)
        @containers[vnodename].configure()
      end

      def vnode_start(vnodename)
        raise Lib::ResourceNotFoundError, vnodename \
           unless @vplatform.get_vnode(vnodename)
        @containers[vnodename].start()
      end

      def vnode_stop(vnodename)
        raise Lib::ResourceNotFoundError, vnodename \
           unless @vplatform.get_vnode(vnodename)
        @containers[vnodename].stop()
      end

      def vnode_destroy(vnode)
        raise unless vnode.is_a?(Resource::VNode)
        @vplatform.destroy_vnode(vnode)
        @containers[vnode.name].destroy if @containers[vnode.name]
        @containers[vnode.name] = nil
      end

      def destroy(resource)
        if resource.is_a?(Resource::VNode)
          vnode_destroy(resource)
        end
      end

      def vroute_add(vroute)
        @vroutes << vroute
      end

      def network_limitation_add(limitations)
        @vnetlimit.add_limitations(limitations)
        NetworkLimitation.apply(limitations)
      end
    end

  end
end
