module LXCWrapper # :nodoc: all

  class ConfigFile
    DEFAULT_CONFIG="lxc.tty = 4
      lxc.pts = 1024
      lxc.cgroup.devices.deny = a
      # /dev/null and zero
      lxc.cgroup.devices.allow = c 1:3 rwm
      lxc.cgroup.devices.allow = c 1:5 rwm
      # consoles
      lxc.cgroup.devices.allow = c 5:1 rwm
      lxc.cgroup.devices.allow = c 5:0 rwm
      lxc.cgroup.devices.allow = c 4:0 rwm
      lxc.cgroup.devices.allow = c 4:1 rwm
      # /dev/{,u}random
      lxc.cgroup.devices.allow = c 1:9 rwm
      lxc.cgroup.devices.allow = c 1:8 rwm
      lxc.cgroup.devices.allow = c 136:* rwm
      lxc.cgroup.devices.allow = c 5:2 rwm
      # rtc
      lxc.cgroup.devices.allow = c 254:0 rwm"

      def self.generate(vnode,filepath)
        File.open(filepath, 'w') do |f| 
          f.puts DEFAULT_CONFIG
          f.puts "lxc.utsname = #{vnode.name}"
          if vnode.filesystem.shared
            f.puts "lxc.rootfs = #{vnode.filesystem.sharedpath}"
          else
            f.puts "lxc.rootfs = #{vnode.filesystem.path}"
          end
          f.puts "# mounts point"
          f.puts "lxc.mount.entry=proc #{vnode.filesystem.path}/proc " \
            "proc nodev,noexec,nosuid 0 0"
          f.puts "lxc.mount.entry=devpts #{vnode.filesystem.path}/dev/pts " \
            "devpts defaults 0 0"
          f.puts "lxc.mount.entry=sysfs #{vnode.filesystem.path}/sys " \
            "sysfs defaults  0 0"

          open("#{vnode.filesystem.path}/etc/network/interfaces", "w") do |froute|
          open("#{vnode.filesystem.path}/etc/rc.local", "w") do |frclocal|
            frclocal.puts("#!/bin/sh -e\n")
            frclocal.puts('sh /etc/rc.local-`hostname`')
            frclocal.puts("exit 0")
          end

          open("#{vnode.filesystem.path}/etc/rc.local-#{vnode.name}", "w") do |frclocal|
            frclocal.puts("#!/bin/sh -e\n")
            frclocal.puts("echo Connected to virtual node #{vnode.name}")
            frclocal.puts("echo 1 > /proc/sys/net/ipv4/ip_forward") if vnode.gateway?
            froute.puts("auto lo\niface lo inet loopback")
            vnode.vifaces.each do |viface|
              f.puts "lxc.network.type = veth"
              f.puts "lxc.network.link = #{Distem::Lib::NetTools::NAME_BRIDGE}"
              f.puts "lxc.network.name = #{viface.name}"
              f.puts "lxc.network.flags = up"
              f.puts "lxc.network.veth.pair = #{Distem::Lib::NetTools.get_iface_name(vnode,viface)}"
              f.puts "lxc.network.ipv4 = #{viface.address.to_string}"
              frclocal.puts("ip route flush dev #{viface.name}")
              froute.puts("iface #{viface.name} inet static")
              froute.puts("\taddress #{viface.address.to_s}")
            
                
              if viface.vnetwork
                frclocal.puts("ip route add #{viface.vnetwork.address.to_string} dev #{viface.name}")
                froute.puts("\tnetmask #{viface.address.netmask.to_s}")
                froute.puts("\tnetwork #{viface.vnetwork.address.to_s}")

                #compute all routes
                viface.vnetwork.vroutes.each_value do |vroute|
                  frclocal.puts("ip route add #{vroute.dstnet.address.to_string} via #{vroute.gw.address.to_s} dev #{viface.name}") unless vroute.gw.address.to_s == viface.address.to_s
                end

              end
              frclocal.puts("#iptables -t nat -A POSTROUTING -o #{viface.name} -j MASQUERADE") if vnode.gateway?
            end
            if vnode.vcpu
              cores = ""
              vnode.vcpu.vcores.each_value { |vcore| cores += "#{vcore.pcore.physicalid}," }
              cores.chop! unless cores.empty?
              f.puts "lxc.cgroup.cpuset.cpus = #{cores}"
            end
            frclocal.puts("exit 0")
          end
          end
        end
      end
  end

end
