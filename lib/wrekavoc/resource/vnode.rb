require 'wrekavoc'
require 'uri'
require 'ipaddress'

module Wrekavoc
  module Resource

    # Wrekavoc Virtual Node 
    class VNode
      @@ids = 0

      MODE_GATEWAY = "GATEWAY"
      MODE_NORMAL = "NORMAL"

      # The unique id of this Node
      attr_reader :id
      # The filesystem informations of the vnode
      attr_reader :filesystem
      attr_reader :name, :host, :vifaces, :vcpu
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
        @filesystem = FileSystem.new(self,image)
        @gateway = false
        @vifaces = []
        @vcpu = nil
        @status = Status::INIT
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

      def add_vcpu(corenb,freq=nil,linked_cores=false)
        raise Lib::AlreadyExistingResourceError, 'VCPU' if @vcpu
        cores = @host.cpu.alloc_cores(self,corenb)
        @vcpu = VCPU.new(@host.cpu)
        cores.each do |core|
          frequency = 0.0
          if freq and freq.to_f > 0.0
            raise Lib::InvalidParameterError, freq if freq.to_f > core.frequency
            frequency = freq.to_f
          else
            frequency = core.frequency
          end
          @vcpu.add_vcore(core,frequency)
        end
      end

      def remove_vcpu()
        @host.cpu.free_cores(self)
        @vcpu = nil
      end

      def ==(vnode)
        vnode.is_a?(VNode) and (@name == vnode.name)
      end

      def to_s
        return @name
      end
    end

  end
end
