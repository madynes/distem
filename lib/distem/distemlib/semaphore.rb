require 'thread'

module Distem
  module Lib

    #Code snippet from : https://gist.github.com/305986
    class Semaphore
      # The size of the semaphore
      attr_reader :size
      # Create a new Semaphore object
      # ==== Attributes
      # * +size+ The size of the semaphore
      #
      def initialize(size)
        raise InvalidParameterError unless size >= 0
        @size = size
        @val = @size
        @lock = Mutex.new
        @positive = ConditionVariable.new
      end

      # Try to acquire a a resource
      def acquire
        @lock.synchronize do
          if @val == 0
            @positive.wait(@lock)
          end

          @val -= 1
        end
      end

      # Leave a resource
      def release
        @lock.synchronize do
          @val += 1
          @positive.signal
        end
      end

      # Acquire then release a resource
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
