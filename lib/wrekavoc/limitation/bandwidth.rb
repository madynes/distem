require 'wrekavoc'

module Wrekavoc
  module Limitation
    module Network

      class Bandwidth < Property
        attr_reader :rate
        def initialize(paramshash={})
          super()
          @rate = nil
          parse_params(paramshash)
        end

        def parse_params(paramshash)
          super(paramshash)
          @rate = paramshash['rate'] if paramshash['rate']
        end

        def to_hash()
          ret = {}
          ret['type'] = Bandwidth.name
          ret['rate'] = @rate
          return ret
        end
      end

    end
  end
end
