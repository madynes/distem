require 'wrekavoc/resource/pnode'
require 'wrekavoc/resource/viface'
require 'resolv'

module Wrekavoc

  module Resource

    class VNode
      @@ids = 0
      attr_reader :id, :name, :host, :image

      def initialize(host, name, image)
        raise unless host.is_a?(PNode)
        raise unless name.is_a?(String)
        raise unless image.is_a?(String)
        # >>> TODO: validate and check image availability

        @id = @@ids

        if name.empty?
          @name = "vnode" + @id.to_s
        else
          @name = name
        end

        @host = host
        @image = image
        @vifaces = []
        @@ids += 1
      end

      def add_viface(viface)
        raise unless viface.is_a?(VIface)
        @vifaces << viface
      end
    end

  end

end
