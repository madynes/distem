module Wrekavoc
  module Limitation
    module Network

      class Manager
        def self.parse_limitations(vnode,viface,hash)
          ret = {}
          ret['INPUT'] = Rule.new(vnode,viface,Direction::INPUT,hash['INPUT']) \
            if hash['INPUT']

          ret['OUTPUT'] = Rule.new(vnode,viface,Direction::OUTPUT,hash['OUTPUT']) \
            if hash['OUTPUT']

          if hash['FULLDUPLEX']
            raise Lib::InvalidParameterError, 'FULLDUPLEX' \
              if ret['INPUT'] or ret['OUTPUT']
            ret['INPUT'] = Rule.new(vnode,viface,Direction::INPUT,hash['FULLDUPLEX'])
            ret['OUTPUT'] = Rule.new(vnode,viface,Direction::OUTPUT,hash['FULLDUPLEX'])
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
