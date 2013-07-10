
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
        defroute = Shell.run("/bin/ip route list").split(/\n/).grep(/^default /)
        if defroute.empty?
          return ""
        else
          return defroute[0].gsub(/.* dev ([^\s]+)( .*)?/, '\1')
        end
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

      # Gets the inet interface configuration in a form suitable for 'ip addr add'
      # ==== Attributes
      # * +iface+ The network interface name (String)
      # ==== Returns
      # String object
      #
      def self.get_iface_config(iface)
        return Shell.run("/bin/ip addr show dev #{iface}").split(/\n/).grep(/inet /)[0].gsub(/.*inet ([^\s]+ brd [^\s]+).*/, '\1').chomp
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

      # Gets the IP address of the default gateway
      # ==== Returns
      # String object
      def self.get_default_gateway
        cmdret = Shell.run("/bin/ip route list")
        return cmdret.lines.grep(/^default /).first.gsub(/.* via ([0-9.]+).*/, '\1').chomp
      end
      
      # Set up the default bridge that will be used to attach new network interfaces
      def self.set_bridge
        iface = self.get_default_iface()
        cfg = self.get_iface_config(iface)

        str = Shell.run("ifconfig")

        unless str.include?("#{NAME_BRIDGE}")
          # needs to be done before we break eth0
          gw = self.get_default_gateway
          Shell.run("ethtool -G #{self.get_default_iface()} rx 4096 tx 4096 || true")

          Shell.run("brctl addbr #{NAME_BRIDGE}")
          Shell.run("brctl setfd #{NAME_BRIDGE} 0")
          Shell.run("brctl setageing #{NAME_BRIDGE} 3000000")
          Shell.run("/bin/ip addr add dev #{NAME_BRIDGE} #{cfg}")
          Shell.run("/bin/ip link set dev #{NAME_BRIDGE} promisc on")
          Shell.run("/bin/ip link set dev #{NAME_BRIDGE} up")
          Shell.run("brctl addif #{NAME_BRIDGE} #{iface}")
          Shell.run("ifconfig #{iface} 0.0.0.0 up")
          iface = self.get_default_iface()
          unless iface.empty?
            Shell.run("ip route del default dev #{iface}")
          end
          Shell.run("ip route add default dev #{NAME_BRIDGE} via #{gw}")
        end
      end

      # >>> TODO: do unset_bridge 
      # :nodoc:
      def self.unset_bridge
      end

      # Set up the IFB module
      def self.set_ifb(nb=64)
        Shell.run("modprobe ifb numifbs=#{nb}")
      end
      
      # Set up the ARP cache 
      def self.set_arp_cache()
        Shell.run("sysctl -w net.ipv4.neigh.default.base_reachable_time=86400")
        Shell.run("sysctl -w net.ipv4.neigh.default.gc_stale_time=86400")
        Shell.run("sysctl -w net.ipv4.neigh.default.gc_thresh1=100000000")
        Shell.run("sysctl -w net.ipv4.neigh.default.gc_thresh2=100000000")
        Shell.run("sysctl -w net.ipv4.neigh.default.gc_thresh3=100000000")
      end

      # Clean the IFB module
      def self.unset_ifb()
        Shell.run("rmmod ifb")
      end

      # Create a new NIC network interface on the physical node (used to communicate with the VNodes, see Daemon::Admin)
      def self.set_new_nic(address,netmask)
        iface = self.get_default_iface()
        Shell.run("ifconfig #{iface}:#{@@nic_count} #{address} netmask #{netmask}")
        @@nic_count += 1
        return ["#{address}/#{netmask}"]
      end


      # Set up a physical machine network properties
      # ==== Attributes
      # * +max_vifaces+ the maximum number of virtual network interfaces that'll be set on this physical machine
      #
      def self.set_resource(max_vifaces)
        set_arp_cache()
        set_bridge()
        set_ifb(max_vifaces)
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

      # Gets the current MTU of a virtual network interface
      # ==== Attributes
      # * +vnode+ The VNode object
      # * +viface+ The VIface object
      # ==== Returns
      # Integer object
      #
      def self.get_iface_mtu(vnode,viface)
        iface = "#{vnode.name}-#{viface.name}-#{viface.id}"
        cmdret = Shell.run("/sbin/ifconfig #{iface}")
        return cmdret.split("\n").grep(/.*MTU.*/)[0].gsub(/.*MTU:(\d+) .*/, '\1').to_i
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
          ret = (Resolv.getnames(target).include?(LOCALHOST))
        rescue Resolv::ResolvError
          ret = false
        end

        ret = (target == LOCALHOST) unless ret

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
