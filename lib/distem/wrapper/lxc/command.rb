require 'distem'

module LXCWrapper # :nodoc: all

  class Command
    LS_CACHE_TIME=1 #second
    MAX_SIMULTANEOUS_START = 8
    MAX_WAIT_CYCLES=16
    @@contlock = {}
    @@lslock = Mutex.new
    @@lscache = {}
    @@waitlock = Mutex.new
    @@starsem = Distem::Lib::Semaphore.new(MAX_SIMULTANEOUS_START)

    def self.create(contname, configfile, wait=true)
      destroy(contname,wait) if ls().include?(contname)
          
      contsync(contname) {
        Distem::Lib::Shell.run("lxc-create -n #{contname} -f #{configfile}",true)
      }
    end
    
    def self.destroy(contname,wait=true)
      contsync(contname) {
        Distem::Lib::Shell.run("lxc-destroy -n #{contname}",true) if ls().include?(contname)
      }
      wait_disapear(contname) if wait
    end

    def self.destroyall(wait=false)
      ls().each do |cont|
        destroy(cont,wait)
      end
    end

    def self.start(contname,daemon=true,wait=true,strict=true)
      wait_exist(contname) if strict
      @@startsem.synchronize do 
        stop(contname,true,strict) if status(contname) == Status::RUNNING
        contsync(contname) {
          Distem::Lib::Shell.run("lxc-start -n #{contname} #{(daemon ? '-d' : '')}",true)
          wait(contname,Status::RUNNING) if wait
        }
      end
    end

    def self.stop(contname,wait=true,strict=true)
      wait_exist(contname) if strict
      unless status(contname) == Status::STOPPED
        contsync(contname) {
          Distem::Lib::Shell.run("lxc-stop -n #{contname}",true)
          wait(contname,Status::STOPPED) if wait
        }
      end
    end

    def self.stopall(wait=false)
      ls().each do |cont|
        stop(cont,wait,false)
      end
    end

    def self.wait(contname, status)
      @@waitlock.synchronize {
        Distem::Lib::Shell.run("lxc-wait -n #{contname} -s #{status}")
      }
    end

    def self.status(contname)
      contsync(contname) {
       Distem::Lib::Shell.run("lxc-info -n #{contname}",true).split().last
      }
    end

    def self.ls(cache=true)
      ret = nil
      if cache
        @@lscache[:time] = Time.now unless @@lscache[:time]
        @@lscache[:value] = Distem::Lib::Shell.run("lxc-ls",true) unless @@lscache[:value]

        if (Time.now - @@lscache[:time]) >= LS_CACHE_TIME
          if @@lslock.locked?
            @@lslock.synchronize{}
          else
            @@lslock.synchronize {
              @@lscache[:value] = Distem::Lib::Shell.run("lxc-ls",true).split
              @@lscache[:time] = Time.now
            }
          end
        end
        ret = @@lscache[:value]
      else
        ret = Distem::Lib::Shell.run("lxc-ls",true).split
      end
      return ret
    end

    def self.wait_exist(contname)
      cycle=0
      begin
        raise Distem::Lib::ResourceNotFoundError.new contname if cycle > MAX_WAIT_CYCLES
        list = ls()
        sleep(LS_CACHE_TIME) if cycle > 0
        cycle += 1
      end while !(list.include?(contname))
    end

    def self.wait_disapear(contname)
      cycle=0
      begin
        raise Distem::Lib::ResourceNotFoundError.new contname if cycle > MAX_WAIT_CYCLES
        list = ls()
        sleep(LS_CACHE_TIME) if cycle > 0
        cycle += 1
      end while list.include?(contname)
    end

    protected
    def self.contsync(contname)
      @@contlock[contname] = Mutex.new unless @@contlock[contname]
      @@contlock[contname].synchronize {
        yield
      }
    end
  end

end
