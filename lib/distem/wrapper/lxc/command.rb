
module LXCWrapper # :nodoc: all

  class Command
    LS_WAIT_TIME = 1
    MAX_WAIT_CYCLES=16
    @@lxc = Mutex.new

    def self.create(contname, configfile, wait=true)
      destroy(contname,wait) if ls().include?(contname)
      lxc_safe_run("lxc-create -n #{contname} -f #{configfile}",true)
    end

    def self.destroy(contname,wait=true)
      lxc_safe_run("lxc-destroy -n #{contname}",true) if ls().include?(contname)
      wait_disapear(contname) if wait
    end

    def self.destroyall(wait=false)
      ls().each do |cont|
        begin
          destroy(cont,wait)
        rescue Distem::Lib::ShellError
        end
      end
    end

    def self.start(contname,daemon=true,wait=true,strict=true)
      wait_exist(contname) if strict
      stop(contname,true,strict) if status(contname) == Status::RUNNING
      lxc_safe_run("lxc-start -n #{contname} #{(daemon ? '-d' : '')}",true)
      wait(contname,Status::RUNNING) if wait
    end

    def self.stop(contname,wait=true,strict=true)
      #wait_exist(contname) if strict
      unless status(contname) == Status::STOPPED
        lxc_safe_run("lxc-stop -n #{contname}",true)
        wait(contname,Status::STOPPED) if wait
      end
    end

    def self.stopall(wait=false)
      ls().each do |cont|
        begin
          stop(cont,wait,false)
        rescue Distem::Lib::ShellError
        end
      end
    end

    def self.wait(contname, status)
      lxc_safe_run("lxc-wait -n #{contname} -s #{status}")
    end

    def self.status(contname)
      lxc_safe_run("lxc-info -n #{contname}",true).split().last
    end

    def self.ls(cache=true)
      return lxc_safe_run('lxc-ls',true).split(/\n/)
    end

    def self.wait_exist(contname)
      cycle=0
      begin
        raise Distem::Lib::ResourceNotFoundError.new contname if cycle > MAX_WAIT_CYCLES
        list = ls()
        sleep(LS_WAIT_TIME) if cycle > 0
        cycle += 1
      end while !(list.include?(contname))
    end

    def self.wait_disapear(contname)
      cycle=0
      begin
        raise Distem::Lib::ResourceNotFoundError.new contname if cycle > MAX_WAIT_CYCLES
        list = ls()
        sleep(LS_WAIT_TIME) if cycle > 0
        cycle += 1
      end while list.include?(contname)
    end

    def self.clean(wait=false)
      stopall(wait)
      destroyall(wait)
      str = Distem::Lib::Shell.run('pidof lxc-wait || true')
      Distem::Lib::Shell.run('killall lxc-wait') if str and !str.empty?
    end
    
    protected

    #LXC is not thread safe, so no simultaneous execution...
    def self.lxc_safe_run(cmd,simple=false)
      ret = nil
      @@lxc.synchronize {
        ret = Distem::Lib::Shell.run(cmd,simple)
      }
      return ret
    end
  end

end
