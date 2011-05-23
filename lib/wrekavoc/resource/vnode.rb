require 'wrekavoc'
require 'resolv'
require 'uri'
require 'ipaddress'

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
      attr_accessor :gateway

      
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
        @gateway = false
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

      def gateway?
        return @gateway
      end

      def get_viface_by_name(vifacename)
        ret = nil
        @vifaces.each do |viface|
          if viface.name == vifacename
            ret = viface
            break
          end
        end
        return ret
      end

      def get_viface_by_network(network)
        network = network.address if network.is_a?(VNetwork)
        raise network.class.to_s unless network.is_a?(IPAddress)
        
        ret = nil
        @vifaces.each do |viface|
          if network.include?(viface.address)
            ret = viface
            break
          end
        end
        
        return ret
      end

      def connected_to?(vnetwork)
        ret = false
        vifaces.each do |viface|
          if viface.connected_to?(vnetwork)
            ret = true
            break
          end
        end
        return ret
      end
    end

  end
end
