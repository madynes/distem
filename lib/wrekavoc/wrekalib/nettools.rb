require 'wrekavoc'

module Wrekavoc
  module Lib

    class NetTools
      NAME_BRIDGE='br0'
      @@nic_count=1
      @@addr_default=nil

      def self.get_default_iface
        cmdret = Shell.run("/sbin/route") 
        # | grep 'default' | awk '{print \$8}' | tr -d '\n'")
        ret=""
        cmdret.each_line { |s| ret=s.split[7] if s.include?("default") }
        return ret
      end 

      def self.get_iface_addr(iface)
        cmdret = Shell.run("/sbin/ifconfig #{iface}") 
        # | grep 'inet addr' | awk '{print \$2}' | cut -d':' -f2 | tr -d '\n'")
        ret=""
        cmdret.each_line { |s| ret=s.split[1].split(":")[1] if s.include?("inet addr") }
        return ret
      end

      def self.get_default_addr(cache=true)
        if !@@addr_default or !cache
          iface = self.get_default_iface()
          @@addr_default = self.get_iface_addr(iface).strip
        end
        return @@addr_default
      end

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

      def self.set_ifb(nb=8)
        Shell.run("modprobe ifb numifbs=#{nb}")
      end

      def self.set_new_nic(address)
        iface = self.get_default_iface()
        Shell.run("ifconfig #{iface}:#{@@nic_count} #{address}")
        @@nic_count += 1
      end

      def self.get_iface_name(vnode,viface)
        raise unless vnode.is_a?(Resource::VNode)
        raise unless viface.is_a?(Resource::VIface)

        return "#{vnode.name}-#{viface.name}"
      end
    end

  end
end
