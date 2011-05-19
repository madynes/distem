require 'ipaddress'

module Wrekavoc
  module Resource

    # Wrekavoc Virtual Interface (to be attached on a Virtual Node)
    class VIface
      # The name of the Interface
      attr_reader :name
      # The IP address of the Interface
      attr_reader :address
      # The VNetwork this interface is working on
      attr_reader :vnetwork

      # Create a new Virtual Interface
      # ==== Attributes
      # * +name+ The name of the Interface
      # ==== Examples
      #   viface = VIface.new("if0")
      def initialize(name)
        raise if name.empty? or not name.is_a?(String)

        @name = name
        @address = IPAddress::IPv4.new("0.0.0.0/0")
        @vnetwork = nil
        @vroutes = []
      end

      def attach(vnetwork,address)
        @vnetwork = vnetwork
        @address = address
      end

      def attached?
        @vnetwork != nil and @address != nil
      end
    end

  end
end
