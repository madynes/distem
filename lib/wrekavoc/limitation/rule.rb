module Wrekavoc
  module Limitation
    module Network

      class Rule
      attr_reader :vnode, :viface, :direction, :properties
        def initialize(vnode, viface, direction, properties = {})
          raise unless vnode.is_a?(Resource::VNode)
          raise unless viface.is_a?(Resource::VIface)

          @vnode = vnode
          @viface = viface
          @direction = direction
          @properties = []
          parse_properties(properties)
        end

        def add_property(prop)
          raise unless prop.is_a?(Property)
          @properties << prop
        end

        def add_properties(properties)
          raise unless properties.is_a?(Array)
          properties.each { |prop| add_property(prop) }
        end

        def get_property(type)
          ret = nil

          case type
            when Property::Type::BANDWIDTH
              @properties.each do |prop|
                if prop.is_a?(Bandwidth)
                  ret = prop
                  break
                end
              end
            when Property::Type::LATENCY
              @properties.each do |prop|
                if prop.is_a?(Latency)
                  ret = prop
                  break
                end
              end
            else ret = nil
          end

          return ret
        end

        def parse_properties(hash)
          add_property(Bandwidth.new(hash['bandwidth'])) if hash['bandwidth']
          add_property(Latency.new(hash['latency'])) if hash['latency']
        end

        def self.get_algorithm_by_name(name)
          ret = nil
          case name.upcase
            when "TBF"
              ret = Algorithm::TBF
            when "HTB"
              ret = Algorithm::HTB
            else
              ret = nil
          end

          return ret
        end
      end

    end
  end
end
