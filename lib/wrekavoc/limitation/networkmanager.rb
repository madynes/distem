module Wrekavoc
  module Limitation

    class NetworkManager
      def initialize()
        @limitations = {}
      end

      def add_limitation(limitation)
        raise unless limitation.is_a?(Network)

        @limitations[limitation.vnode] = [] unless @limitations[limitation.vnode]
        @limitations[limitation.vnode] << limitation
      end

      def get_limitations(vnode)
        return @limitations[limitation.vnode]
      end

      def self.get_limitation_by_type(limitations,type)
        ret = nil

        case type
          when Network::Type::BANDWIDTH
            limitations.each do |limitation|
              if limitation.is_a?(Bandwidth)
                ret = limitation
                break
              end
            end
          when Network::Type::LATENCY
            limitations.each do |limitation|
              if limitation.is_a?(Latency)
                ret = limitation
                break
              end
            end
          else ret = nil
        end

        return ret
      end
    end

  end
end
