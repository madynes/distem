require 'ipaddress'

module Wrekavoc
  module Resource

    # Wrekavoc Virtual Interface (to be attached on a Virtual Node)
    class VIface
      @@ids = 0
      # The unique identifier of the Interface
      attr_reader :id
      # The name of the Interface
      attr_reader :name
      # The IP address of the Interface
      attr_reader :address
      # The VNetwork this interface is working on
      attr_reader :vnetwork

      # Create a new Virtual Interface
      # ==== Attributes
      # * +name+ The name of the Interface
      # ==== Examples
      #   viface = VIface.new("if0")
      def initialize(name)
        raise if name.empty? or not name.is_a?(String)

        @id = @@ids
        @name = name
        @address = IPAddress::IPv4.new("0.0.0.0/0")
        @vnetwork = nil
        @vroutes = []
        @@ids += 1
      end

      def attach(vnetwork,address)
        raise Lib::AlreadyExistingResourceError, @name if @vnetwork
        @vnetwork = vnetwork
        @address = address
      end

      def detach(vnetwork)
        @vnetwork = nil
        @address = IPAddress::IPv4.new("0.0.0.0/0")
      end

      def attached?
        @vnetwork != nil and @address != nil
      end

      def connected_to?(vnetwork)
        return (vnetwork ? vnetwork.address.include?(@address) : false)
      end

      def ==(viface)
        viface.is_a?(VIface) and (@name == viface.name)
      end

      def to_hash()
        ret = {}
        ret['id'] = @id.to_s
        ret['name'] = @name
        ret['address'] = @address.to_string
        ret['connected_to'] = (@vnetwork ? @vnetwork.name : 'nil')
        return ret
      end
    end

  end
end
