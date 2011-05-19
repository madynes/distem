require 'wrekavoc'
require 'ipaddress'

module Wrekavoc
  module Resource

    class VNetwork
      attr_reader :address, :name, :vnodes, :vroutes
      @@id = 0

      #address = ip/mask or ip/cidr
      def initialize(address,name="")
        name = "vnetwork#{@@id}" if name.empty?
        @name = name
        if address.is_a?(IPAddress)
          @address = address.network
        else
          @address = IPAddress::IPv4.new(address).network
        end
        @vnodes = {}
        @vroutes = {}

        @curaddress = @address.first
        @@id += 1
      end 

      def add_vnode(vnode,viface)
        #To clone if modifications in inc_curaddress
        #Atm one VNode can only be attached one time to a VNetwork
        @vnodes[vnode] = viface
        viface.attach(self,@curaddress)
        inc_curaddress()
      end

      def add_vroute(vroute)
        #Replace the route if it already exists
        raise unless vroute.dstnet
        @vroutes[vroute.dstnet] = vroute
      end

      def get_list
        ret = ""
        @vnodes.each do |vnode,viface|
          ret = "#{vnode.name}(#{viface.name}) #{viface.address.to_s}\n"
        end
        return ret
      end

      protected
      def inc_curaddress
        tmp = @curaddress.u32
        tmp += 1
        @curaddress = IPAddress::IPv4.parse_u32(tmp,@curaddress.prefix)
      end
    end

  end
end
