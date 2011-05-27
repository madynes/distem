module Wrekavoc
  module Resource

    class VRoute
      attr_reader :srcnet, :dstnet, :gw
      def initialize(srcnet,destnet,gatewaynode)
        @srcnet = srcnet
        @dstnet = destnet
        @gw = gatewaynode
      end
    end

  end
end
