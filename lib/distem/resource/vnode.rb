require 'distem'
require 'uri'
require 'ipaddress'

module Distem
  module Resource

    # Abstact representation of a virtual node resource
    class VNode
      @@ids = 0

      # The virtual node is a gateway node
      MODE_GATEWAY = "GATEWAY"
      # The virtual node is not a gateway node
      MODE_NORMAL = "NORMAL"

      # The unique id of this virtual node
      attr_reader :id
      # The (unique) name of the virtual node
      attr_reader :name
      # The PNode object describing the machine that hosts this virtual node
      attr_reader  :host
      # The Array of VIface representing this node virtual network interfaces resources
      attr_reader  :vifaces
      # The VCPU resource object associated to this virtual node
      attr_reader  :vcpu
      # The FileSystem resource object associated to this virtual node
      attr_reader :filesystem
      # The status of the Virtual node (see Status)
      attr_accessor :status
      # Boolean describing if this node is in gateway mode or not
      attr_accessor :gateway

      
      # Create a new Virtual Node
      # ==== Attributes
      # * +host+ The Physical Node that will host the Virtual one
      # * +name+ The name of that Virtual Node
      # * +image+ The URI to the image that will be used to deploy the node
      #
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

      # Add a virtual network interface to this virtual node
      # ==== Attributes
      # * +viface+ The VIface object
      #
      def add_viface(viface)
        raise unless viface.is_a?(VIface)
        raise Lib::AlreadyExistingResourceError, viface.name \
          if @vifaces.include?(viface)
        @vifaces << viface
      end

      # Remove a virtual network interface from this virtual node
      # ==== Attributes
      # * +viface+ The VIface object
      #
      def remove_viface(viface)
        @vifaces.delete(viface)
      end

      # Check if the virtual node is in gateway mode
      # ==== Returns
      # Boolean value
      #
      def gateway?
        return @gateway
      end

      # Get a virtual network interface associated to this virtual node specifying it's name
      # ==== Attributes
      # * +vifacename+ The name of the virtual network interface
      # ==== Returns
      # VIface object or nil if not found
      #
      def get_viface_by_name(vifacename)
        return @vifaces.select{|viface| viface.name == vifacename}[0]
      end

      # Get the virtual network interface that's allow this virtual node to be connected on a specified virtual network
      # ==== Attributes
      # * +network+ The VNetwork object
      # ==== Returns
      # VIface object or nil if not found
      #
      def get_viface_by_network(network)
        network = network.address if network.is_a?(VNetwork)
        raise network.class.to_s unless network.is_a?(IPAddress)
        
        return @vifaces.select{|viface| network.include?(viface.address)}[0]
      end

      # Check if this virtual node is connected to a specified virtual network
      # ==== Attributes
      # * +vnetwork+ The VNetwork object
      # ==== Returns
      # Boolean value
      #
      def connected_to?(vnetwork)
        raise unless vnetwork.is_a?(VNetwork)
        ret = @vifaces.select{|viface| viface.connected_to?(vnetwork)}
        return (ret.size > 0)
      end

      # Create a virtual CPU on this virtual node specifying it's virtual core number and their frequencies
      # ==== Attributes
      # * +corenb+ The number of virtual cores this virtual CPU have
      # * +freq+ The frequency the cores should have (if the number is between 0 and 1 it'll be a percentage of the physical core frequency this virtual core will be associated to, if not precised, set to 100% of the physical core, otherwise it should be the wished frequency in KHz)
      #
      def add_vcpu(corenb,freq=nil)
        raise Lib::AlreadyExistingResourceError, 'VCPU' if @vcpu
        @vcpu = VCPU.new(@host.cpu)
        frequency = 0.0
        if freq and freq.to_f > 0.0
          frequency = freq.to_f
        else
          frequency = 1
        end
        corenb.times { @vcpu.add_vcore(frequency) }
      end

      # Attach this virtual CPU to the physical one of the virtual node host (associating each virtual core to a physical one)
      # ==== Attributes
      # * +linked_cores+ Specify if the physical cores chosen to be associated with the virtual ones of the VCPU should be cache linked or not (See Core)
      #
      def attach_vcpu(linked_cores=false)
        raise Lib::UninitializedResourceError unless @vcpu
        cores = @host.cpu.alloc_cores(self,@vcpu.vcores.size,linked_cores)
        i = 0
        @vcpu.vcores.each_value do |vcore|
          vcore.attach(cores[i])
          i += 1
        end
      end

      # Removes the virtual CPU associated to this virtual node, detach each virtual core from the physical core it was associated with 
      def remove_vcpu()
        @host.cpu.free_cores(self)
        @vcpu = nil
      end

      # Compare two virtual nodes
      # ==== Attributes
      # * +vnode+ The VNode object
      # ==== Returns
      # Boolean value
      #
      def ==(vnode)
        vnode.is_a?(VNode) and (@name == vnode.name)
      end

      def to_s
        return @name
      end
    end

  end
end
