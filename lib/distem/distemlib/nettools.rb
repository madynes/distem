
module Distem
  module Lib

    # Class that allow to perform physical operations on a physical network resource
    class NetTools
      # Name used for the bridge set up on a physical machine
      DEFAULT_BRIDGE='br0'
      VXLAN_BRIDGE_PREFIX='vxlanbr'
      VXLAN_INTERFACE_PREFIX='vxlan'
      LOCALHOST='localhost' # :nodoc:
      @@nic_count=1
      @@addr_default=nil
      # Hash containing the (interface name, interface address, interface netmask) triplet
      # for a root interface on which a bridge is plugged on
      @@br_info = {}

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

      # Get the netmask of an interface
      # ==== Attributes
      # * +iface+ The network interface name (String)
      # ==== Returns
      # String object
      def self.get_netmask(iface)
        cmd = Shell.run("ifconfig #{iface}")
        return cmd.split(/\n/).grep(/Mask/).first.gsub(/.*Mask:(.*)$/,'\1')
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

      def self.set_bridge(root_interface, default_gw)
        str = Shell.run("ifconfig")
        bridge_name = "br_#{root_interface}"
        unless str.include?(bridge_name)
          @@br_info[bridge_name] = [root_interface, self.get_iface_addr(root_interface), self.get_netmask(root_interface)]
          # needs to be done before we break eth0
          cfg = self.get_iface_config(root_interface)
          Shell.run("ethtool -G #{root_interface} rx 4096 tx 4096 || true")

          Shell.run("brctl addbr #{bridge_name}")
          Shell.run("brctl setfd #{bridge_name} 0")
          Shell.run("brctl setageing #{bridge_name} 3000000")
          Shell.run("/bin/ip addr add dev #{bridge_name} #{cfg}")
          Shell.run("/bin/ip link set dev #{bridge_name} promisc on")
          Shell.run("/bin/ip link set dev #{bridge_name} up")
          Shell.run("brctl addif #{bridge_name} #{root_interface}")
          Shell.run("ifconfig #{root_interface} 0.0.0.0 up")
          # Set the default route only if the default interface has been added into the bridge, in
          # this case the default gateway is passed as a parameter to set_bridge
          if default_gw
            iface = self.get_default_iface()
            unless iface.empty?
              Shell.run("ip route del default dev #{iface}")
            end
            Shell.run("ip route add default dev #{bridge_name} via #{default_gw}")
          end
          return bridge_name
        else
          return nil
        end
      end

      # Unset the bridge and restore the default interface, if possible
      def self.unset_bridge(brname, default_gw)
        interface, ip, netmask = @@br_info[brname]
        @@br_info.delete(brname)
        cmd = ""
        Dir.glob("/sys/class/net/#{brname}/brif/*").each { |i|
          cmd += "brctl delif #{brname} #{File.basename(i)};"
        }
        cmd += "ip link set #{brname} down;"
        cmd += "brctl delbr #{brname};"
        cmd += "ifconfig #{interface} #{ip} netmask #{netmask}"
        if default_gw
          cmd += ";route add -net 0.0.0.0 gw #{default_gw} dev #{interface}"
        end
        Shell.run(cmd)
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
      def self.set_new_nic(address,netmask,iface)
        new_iface = "#{iface}:#{@@nic_count}"
        Shell.run("ifconfig #{new_iface} #{address} netmask #{netmask}")
        @@nic_count += 1
        return new_iface
      end

      # Unset NIC
      def self.unset_nic(name)
        Shell.run("ifconfig #{name} down")
      end

      # Disable IPv6
      def self.disable_ipv6()
        Shell.run('sysctl -w net.ipv6.conf.all.disable_ipv6=1; true')
      end

      # Set up a physical machine network properties
      # ==== Attributes
      # * +max_vifaces+ the maximum number of virtual network interfaces that'll be set on this physical machine
      # * +set_bridge+ boolean specifying if a bridge has to be created
      def self.set_resource(max_vifaces,set_bridge)
        disable_ipv6()
        set_arp_cache()
        set_bridge() if set_bridge
        set_ifb(max_vifaces)
      end

      # Gets the physical name of a virtual network interface
      # ==== Attributes
      # * +vnode+ The VNode object
      # * +viface+ The VIface object
      # ==== Returns
      # String object
      #
      def self.get_iface_name(viface)
        raise unless viface.is_a?(Resource::VIface)
        return "veth#{viface.id}"
      end

      # Gets the current MTU of a virtual network interface
      # ==== Attributes
      # * +vnode+ The VNode object
      # * +viface+ The VIface object
      # ==== Returns
      # Integer object
      #
      def self.get_iface_mtu(viface)
        cmdret = Shell.run("/sbin/ifconfig #{get_iface_name(viface)}")
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

      # Create a VXLAN interface to encapsulate inter-pnode traffic inside VXLAN tunnel
      # ==== Attributes
      # * +id+ identifier of the VXLAN
      # * +mcast_id+ identifier used to generate the address of the multicast group
      # * +address+ address of the related virtual network
      # * +netmask+ netmask of the related virtual network
      # * +default_interface+ specify a default interface used to plug the VXLAN interface
      #
      def self.create_vxlan_interface(id, mcast_id, address,netmask,root_interface)
        vxlan_iface = VXLAN_INTERFACE_PREFIX + id.to_s
        bridge = VXLAN_BRIDGE_PREFIX + id.to_s
        # First, we set up the VXLAN interface
        mcast_addr = IPAddress::IPv4::parse_u32(mcast_id + IPAddress("239.192.0.0").u32).address
        Shell.run("ip link add #{vxlan_iface} type vxlan id #{id} group #{mcast_addr} ttl 10 dev #{root_interface} dstport 4789")
        Shell.run("ip link set up dev #{vxlan_iface}")
        # Then, we create a bridge
        Shell.run("brctl addbr #{bridge}")
        Shell.run("brctl setfd #{bridge} 0")
        Shell.run("brctl setageing #{bridge} 3000000")
        Shell.run("/bin/ip link set dev #{bridge} promisc on")
        Shell.run("/bin/ip link set dev #{bridge} up")
        # And we add the VXLAN interface into the bridge
        Shell.run("brctl addif #{bridge} #{vxlan_iface}")
        Shell.run("ifconfig #{vxlan_iface} 0.0.0.0 up")
      end

      # Remove a VXLAN interface and its related bridge
      # ==== Attributes
      # * +id+ identifier of the VXLAN
      def self.remove_vxlan_interface(id)
        vxlan_iface = VXLAN_INTERFACE_PREFIX + id.to_s
        bridge = VXLAN_BRIDGE_PREFIX + id.to_s
        Shell.run("brctl delif #{bridge} #{vxlan_iface}")
        Shell.run("ip link del #{vxlan_iface}")
        Shell.run("ifconfig #{bridge} down")
        Shell.run("brctl delbr #{bridge}")
      end
    end

  end
end
