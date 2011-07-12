#Code snippet from : https://gist.github.com/305986
module Wrekavoc
  module Lib

    class Semaphore
      def initialize(val)
        raise InvalidParameterError unless val >= 0
        @val = val
        @lock = Mutex.new
        @positive = ConditionVariable.new
      end

      def acquire
        @lock.synchronize do
          while @val == 0
            @positive.wait(@lock)
          end

          @val -= 1
        end
      end

      def release
        @lock.synchronize do
          @val += 1
          @positive.signal
        end
      end

      def synchronize
        acquire
        begin
          yield
        ensure
          release
        end
      end
    end

  end
end
