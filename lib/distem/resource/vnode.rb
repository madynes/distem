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
      attr_accessor  :host
      # The Array of VIface representing this node virtual network interfaces resources
      attr_reader  :vifaces
      # The VCPU resource object associated to this virtual node
      attr_reader  :vcpu
      # The memory limitation object associated to this virtual node
      attr_accessor :vmem
      # The FileSystem resource object associated to this virtual node
      attr_accessor :filesystem
      # The status of the Virtual node (see Status)
      attr_accessor :status
      # Boolean describing if this node is in gateway mode or not
      attr_accessor :gateway
      # SSH key pair to be used on the virtual node (Hash)
      attr_accessor :sshkey


      # Create a new Virtual Node specifying it's filesystem
      # ==== Attributes
      # * +name+ The name of that Virtual Node
      # * +filesystem+ The FileSystem object
      # * +host+ The Physical Node that will host the Virtual one
      # * +ssh_key+ SSH key to be used on the virtual node (Hash with key 'public' and 'private')
      #
      def initialize(name, ssh_key = nil)
        raise unless name.is_a?(String)

        @id = @@ids

        if name.empty?
          @name = "vnode" + @id.to_s
        else
          @name = name
        end

        @host = nil
        @filesystem = nil

        if ssh_key.is_a?(Hash) and !ssh_key.empty?
          @sshkey = ssh_key
        else
          @sshkey = nil
        end
        @gateway = false
        @vifaces = []
        @vcpu = nil
        @vmem = nil
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

      # Get the list of every virtual networks a virtual node is connected to
      # ==== Returns
      # Array of VNetwork objects
      #
      def get_vnetworks
        ret = []
        @vifaces.each do |viface|
          ret << viface.vnetwork if viface.attached? and !ret.include?(viface.vnetwork)
        end
        return ret
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
      # * +val+ The speed of the virtual CPU defined by a frequency or a ratio (percentage of the physical core frequency
      # * +unit+ Define if val is a frequency or a ratio (allowed values are mhz and ratio)
      #
      def add_vcpu(corenb,val,unit)
        raise Lib::AlreadyExistingResourceError, 'VCPU' if @vcpu
        @vcpu = VCPU.new(self)
        corenb.times { @vcpu.add_vcore(val,unit) }
      end

      # Removes the virtual CPU associated to this virtual node, detach each virtual core from the physical core it was associated with
      def remove_vcpu()
        @vcpu.detach if @vcpu and @vcpu.attached?
        @vcpu = nil
      end

      def add_vmem(opts)
        @vmem = VMem.new(opts)
      end

      def update_vmem(opts)
        remove_vmem if @vmem
        add_vmem(opts)
      end

      def remove_vmem
        if @vmem
          @host.memory.deallocate({:mem => @vmem.mem, :swap => @vmem.swap}) if @host
          @vmem.remove()
          @vmem = nil
        end
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
