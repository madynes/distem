
module Distem
  module Resource

      # Abstract representation of Network duplication resource
      class Duplication < VIface::VTraffic::Property
        # The duplication percent (string with % signe, eg: "10%")
        attr_reader :percent
        # Create a new Bandwidth
        # ==== Attributes
        # * +paramshash+ The Hash of the parameters to set (in the form "paramname" => value)
        #
        def initialize(paramshash={})
          super()
          @percent = nil
          parse_params(paramshash)
        end

        # Parameters parsing method
        def parse_params(paramshash)
          super(paramshash)
          @percent = paramshash['percent']
        end

      end
  end
end
