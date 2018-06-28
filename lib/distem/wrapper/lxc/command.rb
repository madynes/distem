
module LXCWrapper # :nodoc: all

  class Command
    LS_WAIT_TIME = 1
    MAX_WAIT_CYCLES=16
    @@lxc = Mutex.new

    def self.create(contname, configfile, wait=true)
      @@lxc.synchronize {
        _destroy(contname,wait)
        lxc_version = Gem::Version.new(get_lxc_version())

        if lxc_version >= Gem::Version.new('3.0.0')
          #Configuration file syntax has changed since LXC3, but it provides a
          #binary to upate from legacy conf. files.
          Distem::Lib::Shell.run("lxc-update-config -c #{configfile}", true)
        end

        if lxc_version >= Gem::Version.new('1.0.8')
          Distem::Lib::Shell.run("lxc-create -n #{contname} -f #{configfile} -t none", true)
        else
          Distem::Lib::Shell.run("lxc-create -n #{contname} -f #{configfile}", true)
        end
      }
    end

    def self.start(contname,daemon=true)
      debugfile = File.join(Distem::Node::Admin::PATH_DISTEM_LOGS,"lxc","lxc-debug-#{contname}")
      @@lxc.synchronize {
        _stop(contname,true) if _status(contname) == Status::RUNNING
        FileUtils.rm_f(debugfile)
        Distem::Lib::Shell.run("lxc-start -n #{contname} -o #{debugfile} #{(daemon ? '-d' : '')}",true)
        _wait(contname,Status::RUNNING)
      }
    end

    def self.freeze(contname)
      @@lxc.synchronize {
        _freeze(contname)
      }
    end

    def self.unfreeze(contname)
      @@lxc.synchronize {
        _unfreeze(contname)
      }
    end

    def self.stop(contname,wait=true)
      @@lxc.synchronize {
        _stop(contname,wait)
      }
    end

    def self.sync(vnode)
      return unless _status(vnode.name) != Status::STOPPED

      getv = lambda { |v| v == "max" ? "max" : "#{v}M" }

      if vnode.vmem
        if vnode.vmem.hierarchy == 'v1'
          Distem::Lib::Shell::run("lxc-cgroup -n #{vnode.name} memory.limit_in_bytes #{getv.call(vnode.vmem.mem)}") \
            if vnode.vmem.mem && vnode.vmem.mem != ''

          Distem::Lib::Shell::run("lxc-cgroup -n #{vnode.name} memory.memsw.limit_in_bytes #{getv.call(vnode.vmem.swap)}") \
            if vnode.vmem.swap && vnode.vmem.swap != ''

        elsif vnode.vmem.hierarchy == 'v2'
          Distem::Lib::Shell::run("lxc-cgroup -n #{vnode.name} memory.high #{getv.call(vnode.vmem.soft_limit)}") \
            if vnode.vmem.soft_limit && vnode.vmem.soft_limit != ''

          Distem::Lib::Shell::run("lxc-cgroup -n #{vnode.name} memory.max #{getv.call(vnode.vmem.hard_limit)}") \
            if vnode.vmem.hard_limit && vnode.vmem.hard_limit != ''

          Distem::Lib::Shell::run("lxc-cgroup -n #{vnode.name} memory.swap.max #{getv.call(vnode.vmem.swap)}") \
              if vnode.vmem.swap && vnode.vmem.swap != ''
        end
      end

      if vnode.filesystem && vnode.filesystem.disk_throttling \
        && vnode.filesystem.disk_throttling.has_key?('limits')

        hrchy = vnode.filesystem.disk_throttling['hierarchy']

        vnode.filesystem.disk_throttling['limits'].each { |limit|
          if limit.has_key?('device')
            major, minor = `stat --printf %t,%T #{limit['device']}`.split(',').map{|n| n.to_i(16)}
            raise Distem::Lib::InvalidParameterError, "Invalid device #{limit['device']}" if !$?.success?

            Distem::Lib::Shell::run("lxc-cgroup -n #{vnode.name} devices.allow 'b #{major}:#{minor} rwm'")
            wbps = limit.has_key?('write_limit')? limit['write_limit']: 'max'
            rbps = limit.has_key?('read_limit')? limit['read_limit'] : 'max'

            if hrchy == 'v2'
              Distem::Lib::Shell::run("lxc-cgroup -n #{vnode.name} io.max '#{major}:#{minor} wbps=#{wbps} rbps=#{rbps}'")
            elsif hrchy == 'v1'
              Distem::Lib::Shell::run("lxc-cgroup -n #{vnode.name} blkio.throttle.write_bps_device '#{major}:#{minor} #{wbps}'")
              Distem::Lib::Shell::run("lxc-cgroup -n #{vnode.name} blkio.throttle.read_bps_device '#{major}:#{minor} #{rbps}'")
            end
          end
        }
      end
    end

    def self.clean(wait=false)
      @@lxc.synchronize {
        _stopall(wait)
        _destroyall(wait)
        str = Distem::Lib::Shell.run('pidof lxc-wait || true')
        Distem::Lib::Shell.run('killall lxc-wait') if str and !str.empty?
      }
    end

    def self.destroy(contname,wait=true)
      @@lxc.synchronize {
        _destroy(contname, wait)
      }
    end

    def self.get_lxc_version()
      lxc_version = _command?('lxc-version')? `lxc-version`.split(":")[1].strip : `lxc-ls --version`.chop
      return lxc_version
    end

    private

    def self._destroy(contname,wait)
      if _ls().include?(contname)
        cycles = 0
        finished = false
        while !finished
          out = Distem::Lib::Shell.run("lxc-destroy -n #{contname};rm -rf /var/lib/lxc/#{contname}",true)
          if out.include?('does not exist') && _ls().include?(contname)
            cycles += 1
            sleep(LS_WAIT_TIME)
            finished = true if (cycles > MAX_WAIT_CYCLES)
          else
            finished = true
          end
        end
      end
      _wait_disapear(contname) if wait
    end

    def self._destroyall(wait=false)
      _ls().each do |cont|
        begin
          _destroy(cont,wait)
        rescue Distem::Lib::ShellError
        end
      end
    end

    def self._stop(contname,wait=true)
      unless _status(contname) == Status::STOPPED
        if system('lxc-start --version')
          lxc_major_version = `lxc-start --version`.split('.').first
          Distem::Lib::Shell.run("lxc-stop -n #{contname}",true)
        _wait(contname,Status::STOPPED) if wait
        end
      end
    end

    def self._freeze(contname)
      Distem::Lib::Shell.run("lxc-freeze -n #{contname}",true)
      _wait(contname,Status::FROZEN)
    end

    def self._unfreeze(contname)
      Distem::Lib::Shell.run("lxc-unfreeze -n #{contname}",true)
      _wait(contname,Status::RUNNING)
    end

    def self._stopall(wait=false)
      _ls().each do |cont|
        begin
          _stop(cont,wait)
        rescue Distem::Lib::ShellError
        end
      end
    end

    def self._wait(contname, status)
      Distem::Lib::Shell.run("lxc-wait -n #{contname} -s #{status}")
    end

    def self._status(contname)
      Distem::Lib::Shell.run("lxc-info -n #{contname} -s",true).split().last
    end

    def self._ls(cache=true)
      return Distem::Lib::Shell.run('lxc-ls -1',true).split(/\n/)
    end

    def self._wait_disapear(contname)
      cycle=0
      begin
        raise Distem::Lib::ResourceNotFoundError.new contname if cycle > MAX_WAIT_CYCLES
        list = _ls()
        sleep(LS_WAIT_TIME) if cycle > 0
        cycle += 1
      end while list.include?(contname)
    end

    def self._command?(name)
      `which #{name}`
      $?.success?
    end

  end
end
