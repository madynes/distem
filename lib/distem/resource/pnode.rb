require 'resolv'

module Distem
  module Resource

    # Abstract representation of a physical machine/node (the machine that will be used to launch some virtual nodes) 
    class PNode
      @@ids = 0
      # The unique id of the machine
      attr_reader :id
      # The IP address of the machine
      attr_reader :address
      # The machine's CPU description
      attr_accessor :cpu
      # The machine's memory description
      attr_accessor :memory
      # The status in which the Node is (see Status)
      attr_accessor :status
      # The emulation algorithms that are used on this physical node (Hash)
      attr_accessor :algorithms
      # The number of local vifaces
      attr_accessor :local_vifaces

      # Deprecated, used to contact the physical node if the SSH key file is not set
      attr_reader :ssh_user, :ssh_password

      # Create a new PNode
      # ==== Attributes
      # * +hostname+ The hostname/address of the physical machine 
      # ==== Examples
      #   pnode = PNode.new("10.16.0.1")
      #   OR
      #   pnode = PNode.new("my-node.lan")
      #
      def initialize(hostname, ssh_user="root", ssh_password="")
        @id = @@ids
        begin
          @address = Resolv.getaddress(hostname)
        rescue Resolv::ResolvError
          raise Lib::InvalidParameterError, hostname
        end
        @cpu = CPU.new
        # mem and swap are stored in MB
        mem = `grep MemTotal /proc/meminfo`.gsub(/[^\d]/, '').to_i / 1024
        swap = `grep SwapTotal /proc/meminfo`.gsub(/[^\d]/, '').to_i / 1024
        @memory = Memory.new(mem, swap)

        @ssh_user = ssh_user
        @ssh_password = ssh_password
        @status = Status::INIT
        @algorithms = {}
        @algorithms[:cpu] = Algorithm::CPU::HOGS

        @@ids += 1
        @local_vifaces = 0
      end

      # Compare two PNodes (based on the host address)
      # ==== Returns
      # Boolean value
      def ==(pnode)
        pnode.is_a?(PNode) and (@address == pnode.address)
      end
    end

  end  
end
