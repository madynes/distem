require 'wrekavoc'

module Wrekavoc
  module Resource

      # Abstract representation of Network Latency resource
      class Latency < VIface::VTraffic::Property
        # The delay (String at 'tc' form such as "3ms")
        attr_reader :delay
        # Create a new Bandwidth
        # ==== Attributes
        # * +paramshash+ The Hash of the parameters to set (in the form "paramname" => value)
        #
        def initialize(paramshash={})
          super()
          @delay = nil
          parse_params(paramshash)
        end

        # Parameters parsing method
        def parse_params(paramshash)
          super(paramshash)
          @delay = paramshash['delay'] if paramshash['delay']
        end
      end

  end
end
