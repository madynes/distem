module Distem
  module Resource

    # Abstract representation of a virtual route used to link two virtual networks
    class VRoute
      @@ids = 0
      # The source VNetwork
      attr_reader :srcnet
      # The destination VNetwork
      attr_reader  :dstnet
      # The IPAddress object describing the IP address of the VNode/VIface used to get from source to destination
      attr_reader  :gw
      # The unique identifier of the virtual route
      attr_reader :id

      # Create a new VRoute
      # === Attributes
      # * +srcnet+ The source VNetwork object
      # * +dstnet+ The destination VNetwork object
      # * +gwaddr+ The IPAddress object describing the IP address of the VNode/VIface used to get from source to destination

      def initialize(srcnet,dstnet,gwaddr)
        raise unless srcnet.is_a?(VNetwork)
        raise unless dstnet.is_a?(VNetwork)
        raise unless gwaddr.is_a?(IPAddress)
        raise Lib::InvalidParameterError, gwaddr.to_string \
          unless srcnet.address.include?(gwaddr)

        @srcnet = srcnet
        @dstnet = dstnet
        @gw = gwaddr
        @id = @@ids
        @@ids += 1
      end

      # Compares two virtual routes
      # ==== Returns
      # Boolean value
      #
      def ==(vroute)
        vroute.is_a?(VRoute) and (@srcnet == vroute.srcnet) \
          and (@dstnet == vroute.dstnet) # and (@gw == vroute.gw)
      end

      def to_s()
        return "#{@srcnet.address.to_string} to #{@dstnet.address.to_string} via #{@gw.to_s}"
      end
    end

  end
end
