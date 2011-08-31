require 'distem'

module Distem
  module Lib

    # Class that allow to perform physical operations on a physical network resource
    class NetTools
      # Name used for the bridge set up on a physical machine
      NAME_BRIDGE='br0'
      LOCALHOST='localhost' # :nodoc:
      # Maximal size for a network interface name (from GNU/Linux specifications)
      IFNAMEMAXSIZE=15
      @@nic_count=1
      @@addr_default=nil

      # Gets the name of the default network interface used for network communications
      # ==== Returns
      # String object
      def self.get_default_iface
        cmdret = Shell.run("/sbin/route") 
        # | grep 'default' | awk '{print \$8}' | tr -d '\n'")
        ret=""
        cmdret.each_line { |s| ret=s.split[7] if s.include?("default") }
        return ret
      end 

      # Gets the IP address of a specified network interface
      # ==== Attributes
      # * +iface+ The network interface name (String)
      # ==== Returns
      # String object
      #
      def self.get_iface_addr(iface)
        cmdret = Shell.run("/sbin/ifconfig #{iface}") 
        # | grep 'inet addr' | awk '{print \$2}' | cut -d':' -f2 | tr -d '\n'")
        ret=""
        cmdret.each_line { |s| ret=s.split[1].split(":")[1] if s.include?("inet addr") }
        return ret
      end

      # Gets the IP address of the default network interface used for network communications
      # ==== Returns
      # String object
      def self.get_default_addr(cache=true)
        if !@@addr_default or !cache
          iface = self.get_default_iface()
          @@addr_default = self.get_iface_addr(iface).strip
        end
        return @@addr_default
      end

      # Set up the default bridge that will be used to attach new network interfaces
      def self.set_bridge
        iface = self.get_default_iface()
        addr = self.get_default_addr()

        str = Shell.run("ifconfig")

        unless str.include?("#{NAME_BRIDGE}")
          Shell.run("brctl addbr #{NAME_BRIDGE}")
          Shell.run("brctl setfd #{NAME_BRIDGE} 0")
          Shell.run("ifconfig #{NAME_BRIDGE} #{addr} promisc up")
          Shell.run("brctl addif #{NAME_BRIDGE} #{iface}")
          Shell.run("ifconfig #{iface} 0.0.0.0 up")
          iface = self.get_default_iface()
          unless iface.empty?
            Shell.run("ip route del default dev #{iface}")
          end
          Shell.run("ip route add default dev #{NAME_BRIDGE}")
        end
      end

      # >>> TODO: do unset_bridge 
      # :nodoc:
      def self.unset_bridge
      end

      # Set up the IFB module
      def self.set_ifb(nb=8)
        Shell.run("modprobe ifb numifbs=#{nb}")
      end

      # Clean the IFB module
      def self.unset_ifb()
        Shell.run("rmmod ifb")
      end

      # Create a new NIC network interface on the physical node (used to communicate with the VNodes, see Daemon::Admin)
      def self.set_new_nic(address)
        iface = self.get_default_iface()
        Shell.run("ifconfig #{iface}:#{@@nic_count} #{address}")
        @@nic_count += 1
      end

      # Gets the physical name of a virtual network interface
      # ==== Attributes
      # * +vnode+ The VNode object
      # * +viface+ The VIface object
      # ==== Returns
      # String object
      #
      def self.get_iface_name(vnode,viface)
        # >>> TODO: Remove vnode parameter)
        raise unless vnode.is_a?(Resource::VNode)
        raise unless viface.is_a?(Resource::VIface)

        ret = "#{vnode.name}-#{viface.name}-#{viface.id}"
        binf = (ret.size >= IFNAMEMAXSIZE ? ret.size-IFNAMEMAXSIZE : 0)
        ret = ret[binf..ret.size]
        
      end

      # Check if an IP address is local to this physical node
      # ==== Attributes
      # * +address+ The IP address (String)
      # ==== Returns
      # Boolean value
      #
      def self.localaddr?(address)
        raise unless address.is_a?(String)

        begin
          target = Resolv.getaddress(address)
        rescue Resolv::ResolvError
          raise Lib::InvalidParameterError, address
        end

        #Checking if the address is the loopback
        begin
          ret = (Resolv.getname(target) == Lib::NetTools::LOCALHOST)
        rescue Resolv::ResolvError
          ret = false
        end

        #Checking if the address is the one of the default interface
        ret = (Lib::NetTools.get_default_addr == target) unless ret

        #Checking if the address is the one of the ip associated with the hostname of the machine
        unless ret
          begin
            ret = (Resolv.getaddress(Socket.gethostname) == target)
          rescue Resolv::ResolvError
            ret = false
          end
        end
         
        return ret
      end
    end

  end
end
