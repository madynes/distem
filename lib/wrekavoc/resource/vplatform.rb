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

      def add_vnode(vnode)
        raise unless vnode.is_a?(VNode)
        raise unless vnode.host.is_a?(PNode)

        add_pnode(vnode.host)
        @vnodes[vnode.name] = vnode
      end

      def add_pnode(pnode)
        @pnodes[pnode.address] = pnode unless @pnodes.has_key?(pnode.address)
      end

      def add_vnetwork(vnetwork)
        raise unless vnetwork.is_a?(VNetwork)

        @vnetworks[vnetwork.name] = vnetwork 
      end

      def add_vroute(vroute)
        raise unless vroute.is_a?(VRoute)

        @vroutes << vroute
      end

      def get_pnode_by_address(address)
        # >>> TODO: validate ip address
        return @pnodes[Resolv.getaddress(address)]
      end

      def get_pnode_by_name(name)
        return (@vnodes[name] ? @vnodes[name].host : nil)
      end

      def get_pnode_randomly()
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

      def destroy_vnode(vnodename)
        @vnodes[vnodename] = nil
      end
    end

  end
end
