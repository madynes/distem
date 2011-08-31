require 'resolv'

module Wrekavoc
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
        @memory = Memory.new

        @ssh_user = ssh_user
        @ssh_password = ssh_password
        @status = Status::INIT

        @@ids += 1
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
