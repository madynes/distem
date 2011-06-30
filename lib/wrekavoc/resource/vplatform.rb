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
      end

      def add_pnode(pnode)
        raise unless pnode.is_a?(PNode)
        raise Lib::AlreadyExistingResourceError, pnode.address.to_s \
          if @pnodes[pnode.address]

        @pnodes[pnode.address] = pnode 
      end

      def remove_pnode(pnode)
        raise unless pnode.is_a?(PNode)
        @pnodes.delete(pnode.address)
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

      def add_vnode(vnode)
        raise unless vnode.is_a?(VNode)
        raise unless vnode.host.is_a?(PNode)
        raise Lib::AlreadyExistingResourceError, vnode.name \
          if @vnodes[vnode.name]

        @vnodes[vnode.name] = vnode 
      end

      def remove_vnode(vnode)
        raise unless vnode.is_a?(VNode)
        # Remove the vnode on each vnetwork it's connected
        @vnetworks.each_value do |vnetwork|
          if vnetwork.get_vnode(vnode.name)
            # Remove every vroute vnode have a role on
            vnetwork.vroutes.each_value do |vroute|
                if vnetwork.get_vnode_viface(vnode).address.to_s == vroute.gw.to_s
                  vnetwork.remove_vroute(vroute)
                end
            end
            vnetwork.remove_vnode(vnode)
          end
        end
        @vnodes.delete(vnode.name)
      end

      def get_vnode(name)
        return (@vnodes.has_key?(name) ? @vnodes[name] : nil)
      end

      def add_vnetwork(vnetwork)
        raise unless vnetwork.is_a?(VNetwork)
        raise Lib::AlreadyExistingResourceError, vnetwork.address.to_string \
          if @vnetworks[vnetwork.address.to_string]
        @vnetworks.each_value do |vnet|
          raise Lib::AlreadyExistingResourceError, vnetwork.name \
            if vnetwork.name == vnet.name
        end

        @vnetworks[vnetwork.address.to_string] = vnetwork 
      end

      def remove_vnetwork(vnetwork)
        raise unless vnetwork.is_a?(VNetwork)
        # Remove all associated vroutes
        @vnetworks.each_value do |vnet|
          next if vnet == vnetwork
          vnet.vroutes.each_value do |vroute|
            vnet.remove_vroute(vroute) if vroute.dstnet == vnetwork
          end
        end
        vnetwork.destroy()
        @vnetworks.delete(vnetwork.address.to_string)
      end

      def get_vnetwork_by_name(name)
        ret = nil
        @vnetworks.each_value do |vnetwork|
          if vnetwork.name == name
            ret = vnetwork
            break
          end
        end
        return ret
      end

      def get_vnetwork_by_address(address)
        raise unless (address.is_a?(String) or address.is_a?(IPAddress))
        ret = nil
        begin
          address = IPAddress.parse(address) if address.is_a?(String)
          address = address.network
        rescue ArgumentError
          return nil
        end

        ret = @vnetworks[address.to_string]
        unless ret
          @vnetworks.each_value do |vnetwork|
            if vnetwork.address.include?(address)
              ret = vnetwork
              break
            end
          end
        end
        return ret
      end

      def add_vroute(vroute)
        raise unless vroute.is_a?(VRoute)
        vnetwork = @vnetworks[vroute.srcnet.address.to_string]
        raise Lib::ResourceNotFoundError, vroute.srcnet.to_s unless vnetwork
        vnetwork.add_vroute(vroute)
      end

      def remove_vroute(vroute)
        raise unless vroute.is_a?(VRoute)
        vnetwork = @vnetworks[vroute.srcnet.address.to_string]
        raise Lib::ResourceNotFoundError, vroute.srcnet.to_s unless vnetwork
        vnetwork.remove_vroute(vroute)
      end

      def destroy(resource)
        if resource.is_a?(PNode)
          remove_pnode(resource)
        elsif resource.is_a?(VNode)
          remove_vnode(resource)
        elsif resource.is_a?(VNetwork)
          remove_vnetwork(resource)
        elsif resource.is_a?(VRoute)
          remove_vroute(resource)
        end
      end
    end

  end
end
