require 'wrekavoc'
require 'resolv'
require 'uri'

module Wrekavoc

  module Resource

    # Wrekavoc Virtual Node 
    class VNode
      @@ids = 0

      # The unique id of this Node
      attr_reader :id
      # The URI to the -bootstrapped and compressed- image file
      attr_reader :image
      attr_reader :name, :host, :vifaces

      
      # Create a new Virtual Node
      # ==== Attributes
      # * +host+ The Physical Node that will host the Virtual one
      # * +name+ The name of that Virtual Node
      # * +image+ The URI to the image that will be used to deploy the node
      # ==== Examples
      #   pnode = PNode.new("10.16.0.1")
      #   vnode = VNode.new(pnode,"mynode1","http://10.8.0.1/img.tar.bz2")
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
        @image = URI.encode(image)
        @vifaces = []
        @@ids += 1
      end

      # Attach a Virtual Interface to this node
      # ==== Attributes
      # * +viface+ The Virtual Interface to attach
      # ==== Examples
      #   viface = VIface.new("if0","10.16.0.1")
      #   vnode.add_viface(viface)
      def add_viface(viface)
        raise unless viface.is_a?(VIface)
        @vifaces << viface
      end

      def get_viface(vifacename)
        ret = nil
        @vifaces.each do |viface|
          if viface.name == vifacename
            ret = viface
            break
          end
        end
        return ret
      end
    end

  end

end
