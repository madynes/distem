
module Distem
  module Lib

    # Class that allow to perform physical operations on a physical network resource
    class NetTools
      # Name used for the bridge set up on a physical machine
      DEFAULT_BRIDGE='br0'
      VXLAN_BRIDGE_PREFIX='vxbr'
      VXLAN_INTERFACE_PREFIX='vxlan'
      LOCALHOST='localhost' # :nodoc:
      # Maximal size for a network interface name (from GNU/Linux specifications)
      IFNAMEMAXSIZE=15
      @@nic_count=1
      @@addr_default=nil
      @@default_iface = nil
      @@default_iface_ip = nil
      @@default_iface_netmask = nil
      @@default_gw = nil
      @@alias_interfaces = {}

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

      # Set up the default bridge that will be used to attach new network interfaces
      def self.set_bridge
        str = Shell.run("ifconfig")
        unless str.include?("#{DEFAULT_BRIDGE}")
          # needs to be done before we break eth0
          @@default_iface = self.get_default_iface()
          @@default_iface_ip = self.get_iface_addr(@@default_iface)
          @@default_iface_netmask = self.get_netmask(@@default_iface)
          cfg = self.get_iface_config(@@default_iface)
          @@default_gw = self.get_default_gateway
          Shell.run("ethtool -G #{@@default_iface} rx 4096 tx 4096 || true")

          Shell.run("brctl addbr #{DEFAULT_BRIDGE}")
          Shell.run("brctl setfd #{DEFAULT_BRIDGE} 0")
          Shell.run("brctl setageing #{DEFAULT_BRIDGE} 3000000")
          Shell.run("/bin/ip addr add dev #{DEFAULT_BRIDGE} #{cfg}")
          Shell.run("/bin/ip link set dev #{DEFAULT_BRIDGE} promisc on")
          Shell.run("/bin/ip link set dev #{DEFAULT_BRIDGE} up")
          Shell.run("brctl addif #{DEFAULT_BRIDGE} #{@@default_iface}")
          Shell.run("ifconfig #{@@default_iface} 0.0.0.0 up")
          iface = self.get_default_iface()
          unless iface.empty?
            Shell.run("ip route del default dev #{iface}")
          end
          Shell.run("ip route add default dev #{DEFAULT_BRIDGE} via #{@@default_gw}")
        end
      end

      # Unset the bridge and restore the default interface, if possible
      def self.unset_bridge
        if (@@default_iface && @@default_iface_ip && @@default_iface_netmask && @@default_gw)
          cmd = ""
          Dir.glob("/sys/class/net/#{DEFAULT_BRIDGE}/brif/*").each { |i|
            cmd += "brctl delif #{DEFAULT_BRIDGE} #{File.basename(i)};"
          }
          cmd += "ip link set #{DEFAULT_BRIDGE} down;"
          cmd += "brctl delbr #{DEFAULT_BRIDGE};"
          cmd += "ifconfig #{@@default_iface} #{@@default_iface_ip} netmask #{@@default_iface_netmask};"
          cmd += "route add -net 0.0.0.0 gw #{@@default_gw} dev #{@@default_iface}"
          Shell.run(cmd)
        end
        @@default_iface = @@default_iface_ip = @@default_iface_netmask = @@default_gw = nil
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
      def self.set_new_nic(address,netmask,iface=nil)
        iface = self.get_default_iface() if !iface
        new_iface = "#{iface}:#{@@nic_count}"
        Shell.run("ifconfig #{new_iface} #{address} netmask #{netmask}")
        @@nic_count += 1
        return new_iface
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

      # Create a VXLAN interface to encapsulate inter-pnode traffic inside VXLAN tunnel
      # ==== Attributes
      # * +id+ identifier of the VXLAN
      # * +address+ address of the related virtual network
      # * +netmask+ netmask of the related virtual network
      # * +default_interface+ specify a default interface used to plug the VXLAN interface
      #
      def self.create_vxlan_interface(id,address,netmask,default_interface=nil)
        if default_interface
          root_iface = default_interface
        else
          if !@@default_iface
            root_iface = @@default_iface = self.get_default_iface()
          else
            root_iface = @@default_iface
          end
        end
        vxlan_iface = VXLAN_INTERFACE_PREFIX + id.to_s
        bridge = VXLAN_BRIDGE_PREFIX + id.to_s
        # First, we set up the VXLAN interface
        Shell.run("ip link add #{vxlan_iface} type vxlan id #{id} group 239.0.0.#{id} ttl 10 dev #{root_iface} dstport 4789")
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
        # Finally, we create an alias interface attached to the bridge to allow the vnodes "view" from pnodes
        @@alias_interfaces[id] = set_new_nic(address,netmask,bridge)
      end

      # Remove a VXLAN interface and its related bridge
      # ==== Attributes
      # * +id+ identifier of the VXLAN
      def self.remove_vxlan_interface(id)
        vxlan_iface = VXLAN_INTERFACE_PREFIX + id.to_s
        bridge = VXLAN_BRIDGE_PREFIX + id.to_s
        Shell.run("brctl delif #{bridge} #{vxlan_iface}")
        Shell.run("ifconfig #{@@alias_interfaces[id]} down")
        @@alias_interfaces.delete(id)
        Shell.run("ip link del #{vxlan_iface}")
        Shell.run("ifconfig #{bridge} down")
        Shell.run("brctl delbr #{bridge}")
      end
    end

  end
end
