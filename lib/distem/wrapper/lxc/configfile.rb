
module LXCWrapper # :nodoc: all

  class ConfigFile
    PATH_LOG_DIR=File.join(Distem::Node::Admin::PATH_DISTEM_LOGS,'lxc')
    DEFAULT_DEV_RULES=""\
      "lxc.tty = 4\n" \
      "lxc.pts = 1024\n" \
      "lxc.cgroup.devices.deny = a\n" \
      "lxc.cgroup.devices.allow = c 10:232 rwm  # /dev/kvm\n" \
      "lxc.cgroup.devices.allow = c 1:3 rwm  # /dev/null\n" \
      "lxc.cgroup.devices.allow = c 1:5 rwm  # /dev/zero\n" \
      "lxc.cgroup.devices.allow = c 5:1 rwm  # /dev/console\n" \
      "lxc.cgroup.devices.allow = c 5:0 rwm  # /dev/tty\n" \
      "lxc.cgroup.devices.allow = c 1:8 rwm  # /dev/random\n" \
      "lxc.cgroup.devices.allow = c 1:9 rwm  # /dev/urandom\n" \
      "lxc.cgroup.devices.allow = c 136:* rwm  # /dev/pts/*\n" \
      "lxc.cgroup.devices.allow = c 5:2 rwm  #  /dev/pts/ptmx\n" \
      "lxc.cgroup.devices.allow = c 254:0 rwm  # rtc\n"

    def self.generate(vnode,filepath,distempnode)
      # Write lxc config file
      File.open(filepath, 'w') do |f|
        f.puts DEFAULT_DEV_RULES
        f.puts "lxc.utsname = #{vnode.name}"
        if vnode.filesystem.shared
          f.puts "lxc.rootfs = #{vnode.filesystem.sharedpath}"
        else
          f.puts "lxc.rootfs = #{vnode.filesystem.path}"
        end

        Distem::Lib::Shell.run("mkdir -p #{PATH_LOG_DIR}") unless File.directory?(PATH_LOG_DIR)

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
        
        #LXC3 is not able to deal with this option for the moment
        #f.puts "lxc.console = #{File.join(PATH_LOG_DIR,vnode.name)}"

        vnode.vifaces.each do |viface|
          f.puts "lxc.network.type = veth"
          viface_bridge = nil
          case viface.vnetwork.opts['network_type']
          when 'classical'
            if viface.vnetwork.opts.has_key?('root_interface')
              viface_bridge = distempnode.linux_bridges[viface.vnetwork.opts['root_interface']]
            else
              viface_bridge = distempnode.linux_bridges[distempnode.default_network_interface]
            end
          when 'vxlan'
            viface_bridge = Distem::Lib::NetTools::VXLAN_BRIDGE_PREFIX.to_s + viface.vnetwork.opts['vxlan_id'].to_s
          else
            raise
          end
          f.puts "lxc.network.link = #{viface_bridge}"
          f.puts "lxc.network.name = #{viface.name}"
          f.puts "lxc.network.flags = up"
          f.puts "lxc.network.hwaddr = #{viface.macaddress}"
          f.puts "lxc.network.veth.pair = #{Distem::Lib::NetTools.get_iface_name(viface)}"
          f.puts "lxc.network.ipv4 = #{viface.address.to_string}"
        end

        if vnode.vcpu
          cores = ""
          vnode.vcpu.vcores.each_value { |vcore| cores += "#{vcore.pcore.physicalid}," }
          cores.chop! unless cores.empty?
          f.puts "lxc.cgroup.cpuset.cpus = #{cores}"
        end

        #V2 needs a recent kernel version, systemd >=238 and LXC>=3.0 as
        #it requires the unified hierarchy to be enabled by default on the system.
        #Otherwise manual setup of unified hierarchy is required on the system 
        #(kernel parameters, mounting of cgroup2...) as well as the activation of the different
        #controllers (memory, io, ...), on the unified tree.
        #In any case, using v2 controllers requires cgroup_no_v1=c1,c2 in kernel parameters
        #or to use a custom systemd configuration.
        #Swap limitation requires swapaccount=1 for v1 or v2
        if vnode.vmem
          #Only hard limit is implemented in v1 because the soft limit is not reliable
          if !vnode.vmem.has_key?('hierarchy') || vnode.vmem['hierarchy'] == 'v1'
            f.puts "lxc.cgroup.memory.limit_in_bytes = #{vnode.vmem['mem']}M" if vnode.vmem.has_key?('mem') && vnode.vmem['mem'] != ''

          f.puts "lxc.cgroup.memory.memsw.limit_in_bytes = #{vnode.vmem['swap']}M" if vnode.vmem.has_key?('swap') && vnode.vmem['swap'] != ''

          elsif vnode.vmem['hierarchy'] == 'v2'
            #LXC does not do the following by itself, so we have to do it manually
            #https://github.com/lxc/lxc/issues/2379
            cg2_path = Distem::Lib::Shell::run("mount | grep cgroup2 | cut -d ' ' -f3")
            Distem::Lib::Shell::run("echo '+memory' > #{cg2_path.chomp}/cgroup.subtree_control")
            #

            f.puts "lxc.cgroup2.memory.high = #{vnode.vmem['soft_limit']}M" if vnode.vmem.has_key?('soft_limit') && vnode.vmem['soft_limit'] != ''

            f.puts "lxc.cgroup2.memory.max = #{vnode.vmem['hard_limit']}M" if vnode.vmem.has_key?('hard_limit') && vnode.vmem['hard_limit'] != ''

            f.puts "lxc.cgroup2.memory.swap.max = #{vnode.vmem['swap']}M" if vnode.vmem.has_key?('swap') && vnode.vmem['swap'] != ''
          end
        end

        if vnode.filesystem && vnode.filesystem.disk_throttling \
          && vnode.filesystem.disk_throttling.has_key?('limits')

          #default=v2
          hrchy = vnode.filesystem.disk_throttling.has_key?('hierarchy')? vnode.filesystem.disk_throttling['hierarchy'] : 'v2'

          vnode.filesystem.disk_throttling['limits'].each { |limit|
            if limit.has_key?('device')
              major, minor = `stat --printf %t,%T #{limit['device']}`.split(',')
              f.puts "lxc.cgroup.devices.allow = b #{major}:#{minor} rwm #/dev/sdX"
              wbps = limit.has_key?('write_limit')? limit['write_limit']: 'max'
              rbps = limit.has_key?('read_limit')? limit['read_limit'] : 'max'

              if hrchy == 'v2'
                f.puts "lxc.cgroup2.io.max = #{major}:#{minor} wbps=#{wbps} rbps=#{rbps}"
              elsif hrchy == 'v1'
                f.puts "lxc.cgroup.blkio.throttle.write_bps_device = #{major}:#{minor} #{wbps}"
                f.puts "lxc.cgroup.blkio.throttle.read_bps_device = #{major}:#{minor} #{rbps}"
              end
            end
          }
        end

        #Deal with an issue when using systemd (infinite loop inducing high CPU load)
        #http://serverfault.com/questions/658052/systemd-journal-in-debian-jessie-lxc-container-eats-100-cpu
        if system('lxc-start --version')
          lxc_major_version = `lxc-start --version`.split('.').first
          if lxc_major_version == '1'
            f.puts "lxc.autodev = 1"
            f.puts "lxc.kmsg = 0"
          end
        end
      end
    end
  end
end
