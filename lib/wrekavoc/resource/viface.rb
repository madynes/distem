require 'ipaddress'

module Wrekavoc
  module Resource

    # Wrekavoc Virtual Interface (to be attached on a Virtual Node)
    class VIface
      class VTraffic
        class Direction
          INPUT = 'INPUT'
          OUTPUT = 'OUTPUT'
        end

        class Property
          def initialize()
          end

          def parse_params(paramshash)
          end

          def to_s()
            return self.class.name.split('::').last || ''
          end
        end

        attr_reader :viface, :direction, :properties
        def initialize(viface, direction, properties = {})
          @viface = viface
          @direction = direction
          @properties = {}
          parse_properties(properties)
        end


        def add_property(prop)
          raise unless prop.is_a?(Property)
          @properties[prop.class.name] = prop
        end

        def add_properties(properties)
          raise unless properties.is_a?(Array)
          properties.each { |prop| add_property(prop) }
        end

        def get_property(typename)
          return properties[typename]
        end

        def parse_properties(hash)
          add_property(Bandwidth.new(hash['bandwidth'])) if hash['bandwidth']
          add_property(Latency.new(hash['latency'])) if hash['latency']
        end
      end


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

      def set_vtraffic(hash)
        vinput = nil
        voutput = nil

        if hash.is_a?(Hash)
          if hash['FULLDUPLEX']
            hash['INPUT'] = hash['FULLDUPLEX']
            hash['OUTPUT'] = hash['FULLDUPLEX']
          end

          vinput = VTraffic.new(self,VTraffic::Direction::INPUT,hash['INPUT']) \
            if hash['INPUT']
          
          voutput = VTraffic.new(self,VTraffic::Direction::OUTPUT,hash['OUTPUT']) \
            if hash['OUTPUT']
        else
          raise Lib::InvalidParameterError, hash.to_s
        end

        raise Lib::InvalidParameterError, hash.to_s \
          if !vinput and !voutput and !hash.empty?

        raise Lib::AlreadyExistingResourceError, hash['INPUT'] \
          if vinput and @vinput
        @vinput = vinput

        raise Lib::AlreadyExistingResourceError, hash['OUTPUT'] \
          if voutput and @voutput
        @voutput = voutput
      end

      def reset_vtraffic()
        @vinput = nil
        @voutput = nil
      end

      def vtraffic?
        return (@vinput or @voutput)
      end

      def ==(viface)
        viface.is_a?(VIface) and (@name == viface.name)
      end
    end

  end
end
