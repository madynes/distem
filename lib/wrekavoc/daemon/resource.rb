require 'wrekavoc'
require 'resolv'

module Wrekavoc

  module Daemon

    class Resource
      def initialize
        @pnodes = {}
        @vnodes = {}
      end

      def add_vnode(vnode)
        raise unless vnode.is_a?(Wrekavoc::Resource::VNode)
        raise unless vnode.host.is_a?(Wrekavoc::Resource::PNode)

        add_pnode(vnode.host)
        @vnodes[vnode.name] = vnode
      end

      def add_pnode(pnode)
        @pnodes[pnode.address] = pnode unless @pnodes.has_key?(pnode.address)
      end

      def get_pnode_by_address(address)
        # >>> TODO: validate ip address
        return @pnodes[Resolv.getaddress(address)]
      end

      def get_pnode_by_name(name)
        return (@vnodes[name] ? @vnodes[name].host : nil)
      end

      def get_vnode(name)
        return (@vnodes.has_key?(name) ? @vnodes[name] : nil)
      end

      def destroy_vnode(vnode)
        @vnodes[vnode.name] = nil
      end

    end

  end

end
