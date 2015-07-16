require 'ipaddress'

module Distem
  module Resource

    # Abstract representation of a virtual network
    class VNetwork
      @alreadyusedaddr = nil
      # The IPAddress object describing the address range of this virtual network
      attr_reader :address
      # The (unique) name of this virtual network
      attr_reader  :name
      # An Hash describing the VNodes connected to this virtual network (key: VNode object, val: VIface object (the VIface used by the VNode to be connected to the network)
      attr_reader  :vnodes
      # An Hash of the VRoutes associated to this virtual network (key: VRoute.destnet, val: VRoute object)
      attr_reader  :vroutes
      # An Array of physical nodes this virtual network is visible on
      attr_accessor :visibility
      # VXLAN number (used to create bridges and vxlan interfaces on pnodes)
      attr_accessor :vxlan_id

      # Create a new VNetwork
      # ==== Attributes
      # * +address+ The address range to associate to this virtual network (ip/mask, ip/cidr format or IPAddress object)
      # * +name+ The name of the virtual network (if not precised, set to "vnetworkN" where N is a unique id)
      # * +nb_pnodes+ The number of physical nodes
      # * +vxlan_id+ Dedicated id to set up bridge and vxlan interfaces (0 means that vxlan interfaces are not used)
      def initialize(address,name,nb_pnodes,vxlan_id)
        @id = 0
        @name = name
        @vxlan_id = vxlan_id
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
        @visibility = []

        # Address used by the coordinator
        @alreadyusedaddr = nb_pnodes.times.map { |n| IPAddress::IPv4::parse_u32(@address.last.to_u32 - n).to_s }
        @curaddress = @address.first
      end

      # Connect a VNode to this vitual network
      # ==== Attributes
      # * +vnode+ The VNode object
      # * +viface+ The VIface object describing which virtual network interface of the virtual node to use to connect to this network
      # * +address+ (optional) The IP address to set to the virtual node virtual network interface, if not set, picking automagically one of the IP of the range associated to this network
      # ==== Exceptions
      # * +AlreadyExistingResourceError+ if the virtual node is already connected to the network
      # * +UnavailableResourceError+ if the specified IP address is already taken by another VNode
      #
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
          raise Lib::InvalidParameterError, "#{address.to_s}->#{@address.to_string}" \
            unless @address.include?(address)

          raise Lib::UnavailableResourceError, address.to_s \
            if @alreadyusedaddr.include?(address.to_s)

          addr = address.clone
        else
          inc_curaddress() if @alreadyusedaddr.include?(@curaddress.to_s)
          addr = @curaddress.clone
          inc_curaddress()
        end
        @vnodes[vnode] = viface
        @alreadyusedaddr << addr.to_s
        viface.attach(self,addr)
      end

      # Get the VIface a VNode is using to connect to this virtual network
      # ==== Attributes
      # * +vnode+ The VNode object
      # ==== Returns
      # VIface object
      #
      def get_vnode_viface(vnode)
        raise unless vnode.is_a?(VNode)
        return @vnodes[vnode]
      end

      # Get the VNode using a specified address on this virtual network
      # ==== Attributes
      # * +address+ The address String
      # ==== Returns
      # VNode object
      #
      def get_vnode_by_address(address)
        begin
          IPAddress.parse(address) unless address.is_a?(IPAddress)
        rescue ArgumentError
          raise Lib::InvalidParameterError, address
        end
        ret = nil
        @vnodes.each do |vnode,viface|
          if viface.address.to_s.strip == address.to_s.strip
            ret = vnode
            break
          end
        end
        return ret
      end

      # Get the list of physical nodes this virtual network is visible on
      # ==== Returns
      # Array of PNode objects
      #
=begin
      def visibility
        ret = []
        @vnodes.keys.each do |vnode|
          ret << vnode.host if vnode.host and !ret.include?(vnode.host)
        end
        return ret
      end
=end

      # Disconnect a VNode from this virtual network
      # ==== Attributes
      # * +vnode+ The VNode object
      # * +detach+ (optional) Also detach the virtual network interface from this virtual network (see VIface.detach).
      #
      def remove_vnode(vnode,detach = true)
        #Atm one VNode can only be attached one time to a VNetwork
        if @vnodes[vnode]
          @alreadyusedaddr.delete(@vnodes[vnode].address.to_s)
          @vnodes[vnode].detach() if detach
          @vnodes.delete(vnode)
        end
      end

      # Add a new virtual route to this virtual network
      # ==== Attributes
      # * +vroute+ The VRoute object
      #
      def add_vroute(vroute)
        raise unless vroute.is_a?(VRoute)
        raise Lib::AlreadyExistingResourceError, vroute.to_s \
          if @vroutes[vroute.dstnet]
        @vroutes[vroute.dstnet.address.to_string] = vroute
      end

      # Remove a virtual route from this virtual network
      # ==== Attributes
      # * +vroute+ The VRoute object
      #
      def remove_vroute(vroute)
        raise unless vroute.is_a?(VRoute)
        @vroutes.delete(vroute.dstnet.address.to_string)
      end

      # Get a virtual route specifying the route destination
      # ==== Attributes
      # * +dstnet+ The VNetwork object describing the destination virtual network of the virtual route
      #
      def get_vroute(dstnet)
        raise unless dstnet.is_a?(VNetwork)
        return @vroutes[dstnet.address.to_string]
      end

      # Get the virtual node which make the link with another virtual network
      # ==== Attributes
      # * +vnetwork+ The destination VNetwork object
      # * +excludelist+ Recursive function purpose, do not use it
      # ==== Returns
      # VNode object
      #
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

      # Destroy the object (remove every association with other resources)
      def destroy()
        @vnodes.each_key do |vnode|
          remove_vnode(vnode)
        end
        @alreadyusedaddr.delete(@address.last.to_s)
      end

      # Compare two virtual networks
      # ==== Returns
      # Boolean value
      #
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

      def to_s()
        return "#{name}(#{address.to_string})"
      end

      protected
      # Increment the current last automatically affected address
      def inc_curaddress
        tmp = @curaddress.u32
        begin
          tmp += 1
          tmpaddr = IPAddress::IPv4.parse_u32(tmp,@curaddress.prefix)
          raise Lib::UnavailableRessourceError, "IP/#{@name}" \
            if tmpaddr == @address.last
        end while @alreadyusedaddr.include?(tmpaddr.to_s)
        @curaddress = tmpaddr
      end
    end

  end
end
