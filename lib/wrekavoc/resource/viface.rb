module Wrekavoc

  module Resource

    # Wrekavoc Virtual Interface (to be attached on a Virtual Node)
    class VIface
      # The name of the Interface
      attr_reader :name
      # The IP address of the Interface
      attr_reader :ip

      # Create a new Virtual Interface
      # ==== Attributes
      # * +name+ The name of the Interface
      # * +ip+ The IP address of the Interface
      # ==== Examples
      #   viface = VIface.new("if0","10.16.0.1")
      def initialize(name, ip)
        raise if name.empty? or not name.is_a?(String)
        raise if ip.empty? or not ip.is_a?(String)

        @name = name
        # >>> TODO: use IPAddress to validate/store the ip
        @ip = ip
      end
    end

  end

end
