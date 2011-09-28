require 'distem'

module LXCWrapper # :nodoc: all

  class ConfigFile
    PATH_LOG_DIR=File.join(Distem::Lib::FileManager::PATH_DISTEM_LOGS,'lxc')
    DEFAULT_DEV_RULES=""\
      "lxc.tty = 4\n" \
      "lxc.pts = 1024\n" \
      "lxc.cgroup.devices.deny = a\n" \
      "lxc.cgroup.devices.allow = c 1:3 rwm  # /dev/null\n" \
      "lxc.cgroup.devices.allow = c 1:5 rwm  # /dev/zero\n" \
      "lxc.cgroup.devices.allow = c 5:1 rwm  # /dev/console\n" \
      "lxc.cgroup.devices.allow = c 5:0 rwm  # /dev/tty\n" \
      "lxc.cgroup.devices.allow = c 1:8 rwm  # /dev/random\n" \
      "lxc.cgroup.devices.allow = c 1:9 rwm  # /dev/urandom\n" \
      "lxc.cgroup.devices.allow = c 136:* rwm  # /dev/pts/*\n" \
      "lxc.cgroup.devices.allow = c 5:2 rwm  #  /dev/pts/ptmx\n" \
      "lxc.cgroup.devices.allow = c 254:0 rwm  # rtc\n"  

    def self.generate(vnode,filepath)
      # Write lxc config file
      File.open(filepath, 'w') do |f| 
        f.puts DEFAULT_DEV_RULES
        f.puts "lxc.utsname = #{vnode.name}"
        if vnode.filesystem.shared
          f.puts "lxc.rootfs = #{vnode.filesystem.sharedpath}"
        else
          f.puts "lxc.rootfs = #{vnode.filesystem.path}"
        end

        Distem::Lib::Shell.run("mkdir -p #{PATH_LOG_DIR}") \
          unless File.directory?(PATH_LOG_DIR)
        
        f.puts "lxc.mount.entry=proc #{vnode.filesystem.path}/proc " \
          "proc nodev,noexec,nosuid 0 0"
        f.puts "lxc.mount.entry=sysfs #{vnode.filesystem.path}/sys " \
          "sysfs defaults  0 0"
        f.puts "lxc.mount.entry=devpts #{vnode.filesystem.path}/dev/pts " \
          "devpts defaults 0 0"
        # Not necessary at the moment
        # f.puts "lxc.mount.entry=devshm #{vnode.filesystem.path}/dev/shm " \
        #  "tmpfs defaults 0 0"
        # f.puts "lxc.mount.entry=uniq #{vnode.filesystem.path}/home/my " \
        #  "none defaults 0 0"
        f.puts "lxc.console = #{File.join(PATH_LOG_DIR,vnode.name)}"

        vnode.vifaces.each do |viface|
          f.puts "lxc.network.type = veth"
          f.puts "lxc.network.link = #{Distem::Lib::NetTools::NAME_BRIDGE}"
          f.puts "lxc.network.name = #{viface.name}"
          f.puts "lxc.network.flags = up"
          f.puts "lxc.network.veth.pair = #{Distem::Lib::NetTools.get_iface_name(vnode,viface)}"
          f.puts "lxc.network.ipv4 = #{viface.address.to_string}"
        end

        if vnode.vcpu
          cores = ""
          vnode.vcpu.vcores.each_value { |vcore| cores += "#{vcore.pcore.physicalid}," }
          cores.chop! unless cores.empty?
          f.puts "lxc.cgroup.cpuset.cpus = #{cores}"
        end
      end
    end
  end
end
