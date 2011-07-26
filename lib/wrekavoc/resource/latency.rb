require 'wrekavoc'

module Wrekavoc
  module Resource

      class Latency < VIface::VTraffic::Property
        attr_reader :delay
        def initialize(paramshash={})
          super()
          @delay = nil
          parse_params(paramshash)
        end

        def parse_params(paramshash)
          super(paramshash)
          @delay = paramshash['delay'] if paramshash['delay']
        end
      end

  end
end
