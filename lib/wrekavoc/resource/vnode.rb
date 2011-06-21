require 'wrekavoc'
require 'uri'
require 'ipaddress'

module Wrekavoc
  module Resource

    # Wrekavoc Virtual Node 
    class VNode
      @@ids = 0

      class Status
        STOPING=0
        STOPPED=1
        STARTING=2
        STARTED=3
        CONFIGURING=4
        BUSY=5

        def self.to_string(status)
          ret = ""
          case status
            when STOPPED
              ret = "Stopped"
            when STARTED
              ret = "Started"
            when STARTING
              ret = "Starting"
            when STOPING
              ret = "Stoping"
            when CONFIGURING
              ret = "Configuring"
            when BUSY
              ret = "Busy"
            else
              ret = "Unknown"
          end
          return ret
        end
      end

      # The unique id of this Node
      attr_reader :id
      # The URI to the -bootstrapped and compressed- image file
      attr_reader :image
      attr_reader :name, :host, :vifaces
      # The status of the Virtual node (Started|Stopped|Booting|Installing)
      attr_accessor :status
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
        @status = Status::STOPPED
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
        raise Lib::AlreadyExistingResourceError, viface.name \
          if @vifaces.include?(viface)
        @vifaces << viface
      end

      def remove_viface(viface)
        @vifaces.delete(viface)
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

      def ==(vnode)
        vnode.is_a?(VNode) and (@name == vnode.name)
      end

      def to_hash()
        ret = {}
        ret['id'] = @id.to_s
        ret['name'] = @name
        ret['host'] = @host.address.to_s
        ret['image'] = @image
        ret['status'] = Status.to_string(@status)
        ret['gateway'] = @gateway.to_s
        ret['ifaces'] = {}
        @vifaces.each { |viface| ret['ifaces']["#{viface.name}"] = viface.to_hash }
        return ret
      end
    end

  end
end
