module LXCWrapper

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

      def self.generate(vnode,filepath,rootfspath)
        File.open(filepath, 'w') do |f| 
          f.puts DEFAULT_CONFIG
          f.puts "lxc.utsname = #{vnode.name}"
          f.puts "lxc.rootfs = #{rootfspath}"
          f.puts "# mounts point"
          f.puts "lxc.mount.entry=proc #{rootfspath}/proc " \
            "proc nodev,noexec,nosuid 0 0"
          f.puts "lxc.mount.entry=devpts #{rootfspath}/dev/pts " \
            "devpts defaults 0 0"
          f.puts "lxc.mount.entry=sysfs #{rootfspath}/sys " \
            "sysfs defaults  0 0"

          vnode.vifaces.each do |viface|
            f.puts "lxc.network.type = veth"
            f.puts "lxc.network.link = #{Wrekavoc::Node::Admin::NAME_BRIDGE}"
            f.puts "lxc.network.name = #{viface.name}"
            f.puts "lxc.network.flags = up"
            f.puts "lxc.network.veth.pair = #{vnode.name}-#{viface.name}"
            f.puts "lxc.network.ipv4 = #{viface.address.to_string}"
          end
        end
      end
  end

end
