module LXCWrapper # :nodoc: all

  class ConfigFile
    DEFAULT_DEV_RULES="
      lxc.tty = 4
      lxc.pts = 1024
      lxc.cgroup.devices.deny = a
      lxc.cgroup.devices.allow = c 1:3 rwm  # /dev/null
      lxc.cgroup.devices.allow = c 1:5 rwm  # /dev/zero
      lxc.cgroup.devices.allow = c 5:1 rwm  # /dev/console
      lxc.cgroup.devices.allow = c 5:0 rwm  # /dev/tty
      lxc.cgroup.devices.allow = c 4:0 rwm  # /dev/tty0
      lxc.cgroup.devices.allow = c 4:1 rwm  # /dev/tty1
      lxc.cgroup.devices.allow = c 1:8 rwm  # /dev/random
      lxc.cgroup.devices.allow = c 1:9 rwm  # /dev/urandom
      lxc.cgroup.devices.allow = c 136:* rwm  # /dev/pts/*
      lxc.cgroup.devices.allow = c 5:2 rwm  #  /dev/pts/ptmx
      lxc.cgroup.devices.allow = c 254:0 rwm  # rtc"  

      def self.generate(vnode,filepath)
        rootfspath = nil
        if vnode.filesystem.shared
          rootfspath = vnode.filesystem.sharedpath
        else
          rootfspath = vnode.filesystem.path
        end

        File.open(filepath, 'w') do |f| 
          f.puts DEFAULT_DEV_RULES
          f.puts "lxc.utsname = #{vnode.name}"
          f.puts "lxc.rootfs = #{rootfspath}"
          f.puts "# mounts point"
          f.puts "lxc.mount.entry=proc #{vnode.filesystem.path}/proc " \
            "proc nodev,noexec,nosuid 0 0"
          f.puts "lxc.mount.entry=devpts #{vnode.filesystem.path}/dev/pts " \
            "devpts defaults 0 0"
          f.puts "lxc.mount.entry=sysfs #{vnode.filesystem.path}/sys " \
            "sysfs defaults  0 0"

          open("#{rootfspath}/etc/network/interfaces", "w") do |froute|
          open("#{rootfspath}/etc/rc.local", "w") do |frclocal|
            frclocal.puts("#!/bin/sh -e\n")
            frclocal.puts('. /etc/rc.local-`hostname`')
            frclocal.puts("exit 0")
          end

          open("#{rootfspath}/etc/rc.local-#{vnode.name}", "w") do |frclocal|
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
