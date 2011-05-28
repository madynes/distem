require 'wrekavoc'

module Wrekavoc
  module Limitation
    module Network

      class Latency < Property
        attr_reader :delay
        def initialize(delay)
          super()
          @delay = delay
        end
      end

    end
  end
end

