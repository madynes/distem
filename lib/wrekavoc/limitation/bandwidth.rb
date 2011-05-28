require 'wrekavoc'

module Wrekavoc
  module Limitation
    module Network

      class Bandwidth < Property
        attr_reader :rate
        def initialize(rate)
          super()
          @rate = rate
        end
      end

    end
  end
end
