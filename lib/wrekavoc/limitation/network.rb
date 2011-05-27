module Wrekavoc
  module Limitation

    class Network
      class Direction
        INPUT = 0
        OUTPUT = 1
      end

      class Type
        BANDWIDTH=0
        LATENCY=1
      end

      attr_reader :vnode, :viface, :direction, :properties
      def initialize(vnode, viface, direction)
        raise unless vnode.is_a?(Resource::VNode)
        raise unless viface.is_a?(Resource::VIface)

        @vnode = vnode
        @viface = viface
        @direction = direction
        @properties = {}
      end

      def add_property(name, value)
        # >>> TODO: Use the Property class
        @properties[name] = value
      end

      def add_properties(properties)
        # >>> TODO: Use the Property class
        raise unless properties.is_a?(Hash)
        properties.each_pair { |name,value| add_property(name,value) }
      end

      def self.get_direction_by_name(name)
        ret = nil
        case name.upcase
          when "INPUT"
            ret = Direction::INPUT
          when "OUTPUT"
            ret = Direction::INPUT
          else
            ret = nil
        end

        return ret
      end

      def self.get_type_by_name(name)
        ret = nil
        case name.upcase
          when "BANDWIDTH"
            ret = Type::BANDWIDTH
          when "LATENCY"
            ret = Type::LATENCY
          else
            ret = nil
        end

        return ret
      end

      def self.new_by_type(type,vnode,viface,direction,properties)
        ret = nil
        case type
          when Type::BANDWIDTH
            raise unless properties['rate']
            ret = Bandwidth.new(vnode,viface,direction,properties['rate'])
            ret.add_properties(properties)
          when Type::LATENCY
            raise unless properties['delay']
            ret = Latency.new(vnode,viface,direction,properties['delay'])
            ret.add_properties(properties)
          else
            ret = nil
        end

        return ret
      end
    end

  end
end
