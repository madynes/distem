require 'wrekavoc'

module Wrekavoc
  module Limitation
    module Network

      class Property
        class Type
          BANDWIDTH=0
          LATENCY=1
        end
        
        def initialize()
        end

        def parse_params(paramshash)
        end

        def to_s()
          return self.class.name.split('::').last || ''
        end
      end

    end
  end
end
