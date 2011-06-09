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

        def add_limitations(limitations)
          if limitations.is_a?(Rule)
            add_limitation(limitations) 
          else
            raise unless limitations.is_a?(Array)
            limitations.each { |limit| add_limitation(limit) }
          end
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

        def self.parse_limitations(vnode,viface,hash)
          ret = []
          ret << Rule.new(vnode,viface,Direction::INPUT,hash['INPUT']) \
            if hash['INPUT']

          ret << Rule.new(vnode,viface,Direction::OUTPUT,hash['OUTPUT']) \
            if hash['OUTPUT']

          if hash['FULLDUPLEX']
            ret << Rule.new(vnode,viface,Direction::INPUT,hash['FULLDUPLEX'])
            ret << Rule.new(vnode,viface,Direction::OUTPUT,hash['FULLDUPLEX'])
          end

          return ret
        end

        def self.parse_input_limitation(vnode,viface,hash)
            return Rule.new(vnode,viface,Direction::INPUT,hash)
        end

        def self.parse_output_limitation(vnode,viface,hash)
            return Rule.new(vnode,viface,Direction::OUTPUT,hash)
        end
      end

    end
  end
end
