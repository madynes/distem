
module Distem
  module TopologyStore

    # Base interface for the loading methods
    class TopologyReader < StoreBase
      def initialize()
      end

      # Parse the input string and return a hash that describes the vplatform
      # ==== Attributes
      # * +inputstr+ The String to parse
      # ==== Returns
      # Hash object that describes the platform (see Lib::Validator)
      #
      def parse(inputstr)
      end
    end

  end
end
