module Wrekavoc
  module Limitation
    module Network

      class Manager
        def initialize()
          @limitations = {}
        end

        def add_limitation(limitation)
          raise unless limitation.is_a?(Rule)

          @limitations[limitation.vnode] = [] unless @limitations[limitation.vnode]
          @limitations[limitation.vnode] << limitation
        end

        def get_limitation(vnode, viface)
          ret = nil
          @limitations[limitation.vnode].each do |limit|
            if limit.viface == viface
              ret = limit
              break
            end
          end
          return ret
        end

        def get_limitations(vnode)
          return @limitations[limitation.vnode]
        end
      end

    end
  end
end
