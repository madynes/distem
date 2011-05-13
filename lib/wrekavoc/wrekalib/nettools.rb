require 'wrekavoc'

module Wrekavoc
  module Lib

    class NetTools
      NAME_BRIDGE='br0'
      @@nic_count=1

      def self.get_default_iface
        cmdret = Lib::Shell.run("/sbin/route") 
        # | grep 'default' | awk '{print \$8}' | tr -d '\n'")
        ret=""
        cmdret.each_line { |s| ret=s.split[7] if s.include?("default") }
        return ret
      end 

      def self.get_iface_addr(iface)
        cmdret = Lib::Shell.run("/sbin/ifconfig #{iface}") 
        # | grep 'inet addr' | awk '{print \$2}' | cut -d':' -f2 | tr -d '\n'")
        ret=""
        cmdret.each_line { |s| ret=s.split[1].split(":")[1] if s.include?("inet addr") }
        return ret
      end

      def self.get_default_addr
        iface = self.get_default_iface()
        self.get_iface_addr(iface).strip
      end

      def self.set_bridge
        iface = self.get_default_iface()
        addr = self.get_default_addr()

        str = Lib::Shell.run("ifconfig")

        unless str.include?("#{NAME_BRIDGE}")
          Lib::Shell.run("brctl addbr #{NAME_BRIDGE}")
          Lib::Shell.run("brctl setfd #{NAME_BRIDGE} 0")
          Lib::Shell.run("ifconfig #{NAME_BRIDGE} #{addr} promisc up")
          Lib::Shell.run("brctl addif #{NAME_BRIDGE} #{iface}")
          Lib::Shell.run("ifconfig #{iface} 0.0.0.0 up")
          iface = self.get_default_iface()
          unless iface.empty?
            Lib::Shell.run("ip route del default dev #{iface}")
          end
          Lib::Shell.run("ip route add default dev #{NAME_BRIDGE}")
        end
      end

      def self.set_new_nic(address)
        iface = self.get_default_iface()
        Lib::Shell.run("ifconfig #{iface}:#{@@nic_count} #{address}")
        @@nic_count += 1
      end
    end

  end
end
