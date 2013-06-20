module Distem
  module Lib
    module Synchronization
      require 'thread'

      class Semaphore
        def initialize(max)
          @lock = Mutex.new
          @cond = ConditionVariable.new
          @used = 0
          @max = max
        end

        def acquire(n = 1)
          @lock.synchronize {
            while (n > (@max - @used)) do
              @cond.wait(@lock)
            end
            @used += n
          }
        end

        def relaxed_acquire(n = 1)
          taken = 0
          @lock.synchronize {
            while (@max == @used) do
              @cond.wait(@lock)
            end
            taken = (n + @used) > @max ? @max - @used : n
            @used += taken
          }
          return n - taken
        end

        def release(n = 1)
          @lock.synchronize {
            @used -= n
            @cond.signal
          }
        end
      end

      class SlidingWindow
        def initialize(size)
          @sem = Semaphore.new(size)
          @tasks = []
        end

        def add_task(t)
          @tasks << t
        end

        def add_cmd(cmd)
          @tasks << Proc.new {
            system(cmd)
          }
        end

        def run
          tids = []
          @tasks.each { |t|
            tids << Thread.new {
              @sem.acquire
              t.call
              @sem.release
            }
          }
          tids.each { |tid| tid.join }
        end
      end
    end
  end
end
