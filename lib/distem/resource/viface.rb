require 'ipaddress'

module Distem
  module Resource

    # Abstract representation of a virtual network interface
    class VIface
      # Abstract representation of virtual network traffic
      class VTraffic
        # Abstract representation of virtual network traffic direction
        class Direction
          # Input going traffic
          INPUT = 'INPUT'
          # Output going traffic
          OUTPUT = 'OUTPUT'
        end

        # Abstract interface that helps to handle properties a network traffic can have
        class Property
          # Should not be used directly
          def initialize()
          end

          # Parameter parsing method prototype
          def parse_params(paramshash)
          end

          def to_s()
            return self.class.name.split('::').last || ''
          end
        end

        # The VIface associated to this VTraffic
        attr_reader :viface
        # The direction of this VTraffic
        attr_reader  :direction
        # The properties that are describing this VTraffic
        attr_reader  :properties

        # Create a new VTraffic
        # ==== Attributes
        # * +direction+ The direction of this VTraffic ("INPUT" or "OUTPUT", see Direction class)
        # * +viface+ The VIface associated to this VTraffic
        # * +properties+ Hash representing the properties in the form { "propertyname" => { prop1 => val, prop2 => val } }, e.g. {"Bandwidth" => { "rate" => "100mbps" } }.
        #
        def initialize(viface, direction, properties = {})
          @viface = viface
          @direction = direction
          @properties = {}
          parse_properties(properties)
        end


        # Add a new property to the VTraffic 
        # ==== Attributes
        # * +prop+ The Property object
        #
        def add_property(prop)
          raise unless prop.is_a?(Property)
          @properties[prop.class.name] = prop
        end

        # Add new properties to the VTraffic 
        # ==== Attributes
        # * +properties+ An Array of Property objects
        #
        def add_properties(properties)
          raise unless properties.is_a?(Array)
          properties.each { |prop| add_property(prop) }
        end

        # Get a Property specifying it's type
        # ==== Attributes
        # * +typename+ The name of the type, e.g. "Bandwidth"
        #
        def get_property(typename)
          return properties[typename]
        end

        # Parse a Hash of properties 
        # ==== Attributes
        # * +hash+ Hash representing the properties in the form { "propertyname" => { prop1 => val, prop2 => val }, e.g. {"Bandwidth" => { "rate" => "100mbps" } }.
        def parse_properties(hash)
          add_property(Bandwidth.new(hash['bandwidth'])) if hash['bandwidth']
          add_property(Latency.new(hash['latency'])) if hash['latency']
        end
      end


      @@ids = 0
      # The unique identifier of the network interface
      attr_reader :id
      # The name of the network interface
      attr_reader :name
      # The VNode this network interface is associated with
      attr_reader :vnode
      # The IP address of the network interface
      attr_reader :address
      # The mac address of the network interface
      attr_accessor :macaddress
      # The VNetwork this interface is attached to (nil if none)
      attr_reader :vnetwork
      # The output VTraffic description
      attr_accessor :voutput
      # The input VTraffic description
      attr_accessor :vinput
      # The ifb device used by this viface
      attr_accessor :ifb
      # Special rules that override all the virtual traffic
      attr_accessor :latency_filters
      # Bridge on with the viface is attached
      attr_accessor :bridge


      # Create a new VIface
      # ==== Attributes
      # * +name+ The name of the virtual network interface
      # * +vnode+ The VNode object describing the virtual node associated to this virtual network interface
      #
      def initialize(name,vnode)
        raise if name.empty? or not name.is_a?(String)

        @id = @@ids
        @name = name
        @vnode = vnode
        @address = IPAddress::IPv4.new("0.0.0.0/0")
        @macaddress = nil
        @vnetwork = nil
        @vinput = nil
        @voutput = nil
        @vroutes = []
        @@ids += 1
        @ifb = nil
        @filters = nil
      end

      # Attach the virtual network interface to a virtual network specifying it's IP address
      # ==== Attributes
      # * +vnetwork+ The VNetwork object
      # * +address+ The IPAddress object
      def attach(vnetwork,address)
        raise Lib::AlreadyExistingResourceError, @name if @vnetwork
        @vnetwork = vnetwork
        @address = address
      end

      # Detach the virtual network interface from the VNetwork it's connected to
      def detach()
        if attached?
          @vnetwork.remove_vnode(@vnode,false)
          @vnetwork = nil
          @vinput = nil
          @voutput = nil
          @address = IPAddress::IPv4.new("0.0.0.0/0")
        end
      end

      # Check if the virtual network interface is connected to a virtual network
      # ==== Returns
      # Boolean value
      def attached?
        @vnetwork != nil and @address != nil
      end

      # Check if the virtual network interface is connected to a specified virtual network
      # ==== Attributes
      # * +vnetwork+ The VNetwork object describing the virtual network
      # ==== Returns
      # Boolean value
      #
      def connected_to?(vnetwork)
        raise unless vnetwork.is_a?(VNetwork)
        return (vnetwork ? vnetwork.address.include?(@address) : false)
      end

      # Reset the virtual traffic of this virtual network interface
      def reset_vtraffic()
        @vinput = nil
        @voutput = nil
      end

      # Check if a VTraffic is specified for this virtual network interface
      # ==== Returns
      # Boolean value
      #
      def vtraffic?
        return (@vinput or @voutput)
      end

      # Compare two VIfaces (based on their name)
      # ==== Returns
      # Boolean value
      #
      def ==(viface)
        viface.is_a?(VIface) and (@name == viface.name)
      end
    end

  end
end
