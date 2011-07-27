require 'wrekavoc'

module Wrekavoc
  module Node

    class NetworkForge < Forge
      def initialize(viface,algorithm=Algorithm::Network::TBF.new)
        super(viface,algorithm)
      end
    end

  end
end
