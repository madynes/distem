require 'wrekavoc'
require 'resolv'

module Wrekavoc
  module Resource

    class VPlatform
      attr_reader :pnodes, :vnodes, :vnetworks

      def initialize
        @pnodes = {}
        @vnodes = {}
        @vnetworks = {}
        @vroutes = []
      end

      def add_pnode(pnode)
        raise unless pnode.is_a?(PNode)
        raise Lib::AlreadyExistingResourceError, pnode.address.to_s \
          if @pnodes[pnode.address]

        @pnodes[pnode.address] = pnode 
      end

      def add_vnode(vnode)
        raise unless vnode.is_a?(VNode)
        raise unless vnode.host.is_a?(PNode)
        raise Lib::AlreadyExistingResourceError, vnode.name \
          if @vnodes[vnode.name]

        @vnodes[vnode.name] = vnode 
      end

      def add_vnetwork(vnetwork)
        raise unless vnetwork.is_a?(VNetwork)
        raise Lib::AlreadyExistingResourceError, vnetwork.name \
          if @vnetworks[vnetwork.name]

        @vnetworks[vnetwork.name] = vnetwork 
      end

      def add_vroute(vroute)
        raise unless vroute.is_a?(VRoute)

        @vroutes << vroute
      end

      def get_pnode_by_address(address)
        # >>> TODO: validate ip address
        ret = nil
        begin
          ret = @pnodes[Resolv.getaddress(address)]
        rescue Resolv::ResolvError
          ret = nil
        ensure
          return ret
        end
      end

      def get_pnode_by_name(name)
        return (@vnodes[name] ? @vnodes[name].host : nil)
      end

      def get_pnode_randomly()
        raise Lib::UnavailableResourceError, 'PNODE' if @pnodes.empty?
        tmp = @pnodes.keys
        return @pnodes[tmp[rand(tmp.size)]]
      end

      def get_vnode(name)
        return (@vnodes.has_key?(name) ? @vnodes[name] : nil)
      end

      def get_vnetwork_by_name(name)
        return (@vnetworks.has_key?(name) ? @vnetworks[name] : nil)
      end

      def get_vnetwork_by_address(address)
        ret = nil
        @vnetworks.each_value do |vnetwork|
          if vnetwork.address.to_string == address
            ret = vnetwork
            break
          end
        end
        return ret
      end

      def destroy_pnode(pnode)
        raise unless pnode.is_a?(PNode)
        @pnodes[pnode.address] = nil
      end

      def destroy_vnode(vnode)
        raise unless vnode.is_a?(VNode)
        @vnodes[vnode.name] = nil
      end

      def destroy(resource)
        if resource.is_a?(PNode)
          destroy_pnode(resource)
        elsif resource.is_a?(VNode)
          destroy_vnode(resource)
        end
      end
    end

  end
end
