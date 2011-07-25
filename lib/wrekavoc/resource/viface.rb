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
      attr_reader :voutput
      # The Limitation (input traffic) applied to this interface
      attr_reader :vinput
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
        @vinput = nil
        @voutput = nil
        @limited = false
        @vroutes = []
        @@ids += 1
      end

      def attach(vnetwork,address)
        raise Lib::AlreadyExistingResourceError, @name if @vnetwork
        @vnetwork = vnetwork
        @address = address
      end

      def detach()
        if attached?
          @vnetwork.remove_vnode(@vnode,false)
          @vnetwork = nil
          @vinput = nil
          @voutput = nil
          @address = IPAddress::IPv4.new("0.0.0.0/0")
        end
      end

      def attached?
        @vnetwork != nil and @address != nil
      end

      def connected_to?(vnetwork)
        raise unless vnetwork.is_a?(VNetwork)
        return (vnetwork ? vnetwork.address.include?(@address) : false)
      end

      def add_limitations(limitation)
        vinput = nil
        voutput = nil
        #Already parsed hash
        if limitation.is_a?(Hash)
          if limitation['INPUT']
            raise Lib::InvalidParameterError, limitation['INPUT'] \
              unless limitation['INPUT'].is_a?(Limitation::Network::Rule)
            vinput = limitation['INPUT']
          end
          
          if limitation['OUTPUT']
            raise Lib::InvalidParameterError, limitation['OUTPUT'] \
              unless limitation['OUTPUT'].is_a?(Limitation::Network::Rule)
            voutput = limitation['OUTPUT']
          end
        elsif limitation.is_a?(Limitation::Network::Rule)
          if limitation.direction == Limitation::Network::Direction::INPUT
            vinput = limitation
          elsif limitation.direction == Limitation::Network::Direction::OUTPUT
            voutput = limitation
          else
            raise Lib::InvalidParameterError, limitation
          end
        else
          raise Lib::InvalidParameterError, limitation
        end

        raise Lib::AlreadyExistingResourceError, vinput \
          if vinput and @vinput
        @vinput = vinput

        raise Lib::AlreadyExistingResourceError, voutput \
          if voutput and @voutput
        @voutput = voutput
      end

      def remove_limitations()
        @vinput = nil
        @voutput = nil
      end

      def limitation?
        return (@vinput or @voutput)
      end

      def limited?
        return @limited
      end

      def ==(viface)
        viface.is_a?(VIface) and (@name == viface.name)
      end
    end

  end
end
