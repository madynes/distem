
module LXCWrapper # :nodoc: all

  class Command
    LS_WAIT_TIME = 1
    MAX_WAIT_CYCLES=16
    @@lxc = Mutex.new

    def self.create(contname, configfile, wait=true)
      @@lxc.synchronize {
        _destroy(contname,wait)
        Distem::Lib::Shell.run("lxc-create -n #{contname} -f #{configfile}",true)
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
        Distem::Lib::Shell.run("lxc-stop -n #{contname}",true)
        _wait(contname,Status::STOPPED) if wait
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
      return Distem::Lib::Shell.run('lxc-ls',true).split(/\n/)
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
  end
end
