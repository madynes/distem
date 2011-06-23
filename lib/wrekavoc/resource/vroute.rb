module Wrekavoc
  module Resource

    class VRoute
      @@ids = 0
      attr_reader :srcnet, :dstnet, :gw
      def initialize(srcnet,dstnet,gwnode)
        raise unless srcnet.is_a?(VNetwork)
        raise unless dstnet.is_a?(VNetwork)

        @srcnet = srcnet
        @dstnet = dstnet
        @gw = gwnode
        @id = @@ids
        @@ids += 1
      end

      def ==(vroute)
        vroute.is_a?(VRoute) and (@srcnet == vroute.srcnet) \
          and (@dstnet == vroute.dstnet) # and (@gw == vroute.gw)
      end

      def to_hash()
        ret = {}
        ret['id'] = @id.to_s
        ret['networksrc'] = @srcnet.name
        ret['networkdst'] = @dstnet.name
        ret['gateway'] = @gw.to_s
        return ret
      end

      def to_s()
        return "#{@srcnet.address.to_string} to #{@dstnet.address.to_string} via #{@gw.to_s}"
      end
    end

  end
end
