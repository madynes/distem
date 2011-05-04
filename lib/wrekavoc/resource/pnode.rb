require 'resolv'

module Wrekavoc
  module Resource

    # Wrekavoc Physical Node (the physical machine used to deploy Virtual Nodes)
    class PNode
      # The Physical Node was just created 
      STATUS_INIT=0
      # The Physical Node was initialized
      STATUS_RUN=1

      @@ids = 0
      # The unique id of the Node
      attr_reader :id
      # The IP address of the Node
      attr_reader :address
      # The status in which the Node is
      attr_accessor :status

      attr_reader :ssh_user, :ssh_password

      # Create a new Virtual Node
      # ==== Attributes
      # * +hostname+ The hostname/address of the physical machine 
      # ==== Examples
      #   pnode = PNode.new("10.16.0.1")
      #   OR
      #   pnode = PNode.new("my-node.lan")
      def initialize(hostname, ssh_user="root", ssh_password="")
        @id = @@ids
        @address = Resolv.getaddress(hostname)
        @ssh_user = ssh_user
        @ssh_password = ssh_password
        @status = STATUS_INIT

        @@ids += 1
      end

      # Comparaison between two PNodes (based on the host address)
      def ==(pnode)
        @address == pnode.address
      end
    end

  end  
end
