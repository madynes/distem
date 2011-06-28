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
      # The VNode the interface is associated with
      attr_reader :vnode
      # The IP address of the Interface
      attr_reader :address
      # The VNetwork this interface is working on
      attr_reader :vnetwork
      # The Limitation (output traffic) applied to this interface
      attr_reader :limit_output
      # The Limitation (input traffic) applied to this interface
      attr_reader :limit_input
      attr_accessor :limited

      # Create a new Virtual Interface
      # ==== Attributes
      # * +name+ The name of the Interface
      # ==== Examples
      #   viface = VIface.new("if0")
      def initialize(name,vnode)
        raise if name.empty? or not name.is_a?(String)

        @id = @@ids
        @name = name
        @vnode = vnode
        @address = IPAddress::IPv4.new("0.0.0.0/0")
        @vnetwork = nil
        @limit_input = nil
        @limit_output = nil
        @limited = false
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
        raise unless vnetwork.is_a?(VNetwork)
        return (vnetwork ? vnetwork.address.include?(@address) : false)
      end

      def add_limitation(limitation)
        limit_input = nil
        limit_output = nil
        #Already parsed hash
        if limitation.is_a?(Hash)
          if limitation['INPUT']
            raise Lib::InvalidParameterError, limitation['INPUT'] \
              unless limitation['INPUT'].is_a?(Limitation::Network::Rule)
            limit_input = limitation['INPUT']
          end
          
          if limitation['OUTPUT']
            raise Lib::InvalidParameterError, limitation['OUTPUT'] \
              unless limitation['OUTPUT'].is_a?(Limitation::Network::Rule)
            limit_output = limitation['OUTPUT']
          end
        elsif limitation.is_a?(Limitation::Network::Rule)
          if limitation.direction == Limitation::Network::Direction::INPUT
            limit_input = limitation
          elsif limitation.direction == Limitation::Network::Direction::OUTPUT
            limit_output = limitation
          else
            raise Lib::InvalidParameterError, limitation
          end
        else
          raise Lib::InvalidParameterError, limitation
        end

        raise Lib::AlreadyExistingResourceError, limit_input \
          if limit_input and @limit_input
        @limit_input = limit_input

        raise Lib::AlreadyExistingResourceError, limit_output \
          if limit_output and @limit_output
        @limit_output = limit_output
      end

      def remove_limitation(limitation)
        raise unless limitation.is_a?(Hash)
        @limitation_input = nil if limitation['INPUT']
        @limitation_output = nil if limitation['OUTPUT']
      end

      def limited?
        return @limited
      end

      def ==(viface)
        viface.is_a?(VIface) and (@name == viface.name)
      end

      def to_hash()
        ret = {}
        ret['id'] = @id.to_s
        ret['name'] = @name
        ret['vnode'] = @vnode.name
        ret['address'] = @address.to_string
        ret['connected_to'] = (@vnetwork ? @vnetwork.name : 'nil')
        ret['limit_input'] = (@limit_input ? @limit_input.to_hash : 'nil')
        ret['limit_output'] = (@limit_output ? @limit_output.to_hash : 'nil')
        return ret
      end
    end

  end
end
