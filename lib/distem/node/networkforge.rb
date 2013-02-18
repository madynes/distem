#require 'distem'

module Distem
  module Node

    # Allows to modify network physical resources to fit with the virtual resources specifications
    class NetworkForge < Forge
      # Create a new NetworkForge specifying the virtual network interface resource to modify (limit) and the algorithm to use
      # ==== Attributes
      # * +viface+ The VIface object
      # * +algorithm+ The Algorithm::Network object
      #
      def initialize(viface,algorithm=Algorithm::Network::TBF.new)
        super(viface,algorithm)
      end
    end

  end
end
