require 'wrekavoc'
require 'ipaddress'

module Wrekavoc
  module Resource

    class VNetwork
      attr_reader :address, :name, :vnodes, :vroutes
      @@id = 0
      @@alreadyusedaddr = Array.new

      #address = ip/mask or ip/cidr
      def initialize(address,name=nil)
        name = "vnetwork#{@@id}" unless name
        @name = name
        if address.is_a?(IPAddress)
          @address = address.network.clone
        else
          begin
            @address = IPAddress.parse(address).network
          rescue ArgumentError
            raise Lib::InvalidParameterError, address
          end
        end
        @vnodes = {}
        @vroutes = {}

        @curaddress = @address.first
        @@id += 1
      end 

      def add_vnode(vnode,viface,address=nil)
        #Atm one VNode can only be attached one time to a VNetwork
        raise Lib::AlreadyExistingResourceError, vnode.name if @vnodes[vnode]

        addr = nil
        if address
          begin
            address = IPAddress.parse(address) unless address.is_a?(IPAddress)
            address.prefix = @address.prefix.to_i
          rescue ArgumentError
            raise Lib::InvalidParameterError, address
          end
          raise Lib::InvalidParameterError, address.to_s \
            unless @address.include?(address)

          raise Lib::UnavailableResourceError, address.to_s \
            if @@alreadyusedaddr.include?(address.to_s)

          addr = address.clone
        else
          inc_curaddress() if @@alreadyusedaddr.include?(@curaddress.to_s)
          addr = @curaddress.clone
          inc_curaddress()
        end

        @vnodes[vnode] = viface
        @@alreadyusedaddr << addr.to_s
        viface.attach(self,addr)
      end

      def get_vnode(vnodename)
        ret = nil
        @vnodes.each_pair do |vnode,viface|
          if vnode.name == vnodename and viface
            ret = vnode
            break
          end
        end
        return ret
      end

      def get_vnode_viface(vnode)
        raise unless vnode.is_a?(VNode)
        return @vnodes[vnode]
      end

      def remove_vnode(vnode,detach = true)
        #Atm one VNode can only be attached one time to a VNetwork
        @vnodes[vnode].detach(self) if @vnodes[vnode] and detach
        @vnodes[vnode] = nil
      end

      def add_vroute(vroute)
        raise unless vroute.is_a?(VRoute)
        raise Lib::AlreadyExistingResourceError, vroute.to_s \
          if @vroutes[vroute.dstnet]
        @vroutes[vroute.dstnet.address.to_string] = vroute
      end

      def remove_vroute(vroute)
        raise unless vroute.is_a?(VRoute)
        @vroutes[vroute.dstnet.address.to_string] = nil
      end

      def get_vroute(dstnet)
        raise unless dstnet.is_a?(VNetwork)
        return @vroutes[dstnet.address.to_string]
      end

      def get_list
        ret = ""
        @vnodes.each do |vnode,viface|
          ret = "#{vnode.name}(#{viface.name}) #{viface.address.to_s}\n"
        end
        return ret
      end

      def perform_vroute(vnetwork,excludelist=[])
        ret = nil
        excludelist << self
        found = false

        @vnodes.each_key do |vnode|
          vnode.vifaces.each do |viface|
            found = true if viface.connected_to?(vnetwork)

            if viface.vnetwork and !excludelist.include?(viface.vnetwork)
              found = true if viface.vnetwork.perform_vroute(vnetwork,excludelist) 
            end

            break if found
          end

          if found
            ret = vnode
            break
          end
        end

        excludelist.delete(self)

        return ret
      end

      def destroy()
        @vnodes.each_key do |vnode|
          remove_vnode(vnode)
        end
      end

      def ==(vnetwork)
        ret = false
        if vnetwork.is_a?(VNetwork)
          ret = (vnetwork.address.to_string == @address.to_string)
        elsif vnetwork.is_a?(String)
          begin
            addr = IPAddress.parse(vnetwork)
            ret = (addr.to_string == @address.to_string)
          rescue ArgumentError
            ret = false
          end
        else
          ret = false
        end
        return ret
      end

      def to_hash()
        ret = {}
        ret['name'] = @name
        ret['address'] = @address.to_string
        ret['vnodes'] = []
        @vnodes.each_pair do |vnode,viface|
          ret['vnodes'] << vnode.name if viface
        end
        return ret
      end

      def to_s()
        return "#{name}(#{address.to_string})"
      end

      protected
      def inc_curaddress
        tmp = @curaddress.u32
        begin
          tmp += 1
          tmpaddr = IPAddress::IPv4.parse_u32(tmp,@curaddress.prefix)
          raise Lib::UnavailableRessourceError, "IP/#{@name}" \
            if tmpaddr == @address.last
        end while @@alreadyusedaddr.include?(tmpaddr.to_s)
        @curaddress = tmpaddr
      end
    end

  end
end
