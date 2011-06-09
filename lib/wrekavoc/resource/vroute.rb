module Wrekavoc
  module Resource

    class VRoute
      attr_reader :srcnet, :dstnet, :gw
      def initialize(srcnet,destnet,gatewaynode)
        @srcnet = srcnet
        @dstnet = destnet
        @gw = gatewaynode
      end

      def to_hash()
        ret = {}
        ret['networksrc'] = @srcnet.to_hash
        ret['networkdst'] = @dstnet.to_hash
        ret['gateway'] = @gw.to_hash
        return ret
      end
    end

  end
end
