require 'thread'

module Distem
  module DataCollection
    class Probe
      @frequency = nil
      @tid = nil
      @finished = nil
      @opts = nil
      @drift = nil
      attr_reader :data

      def initialize(drift, data, opts)
        @drift = drift
        @data = data
        @opts = opts
        @frequency = opts['frequency']
        @finished = false
      end

      def run
        @tid = Thread.new {
          while !@finished
            sleep(1 / @frequency)
            val = get_value
            @data << [(@drift + Time.now.to_f).round(3), val] if val
          end
        }
      end

      def restart
        @finished = false
        run
      end

      def stop
        @finished = true
        sleep(1 + (1 / @frequency))
        Thread.kill(@tid) if @tid.alive?
      end

      def get_value
        raise  Lib::NotImplementedError
      end
    end
  end
end

