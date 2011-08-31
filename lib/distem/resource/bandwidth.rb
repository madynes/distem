require 'wrekavoc'

module Wrekavoc
  module Resource

      # Abstract representation of Network Bandwidth resource
      class Bandwidth < VIface::VTraffic::Property
        # The rate (String at 'tc' form such as "10mbps")
        attr_reader :rate

        # Create a new Bandwidth
        # ==== Attributes
        # * +paramshash+ The Hash of the parameters to set (in the form "paramname" => value)
        #
        def initialize(paramshash={})
          super()
          @rate = nil
          parse_params(paramshash)
        end

        # Parameters parsing method
        def parse_params(paramshash)
          super(paramshash)
          @rate = paramshash['rate'] if paramshash['rate']
        end
      end

  end
end
