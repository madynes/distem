require 'thread'

module Distem
  module DataCollection
    class ProbeLoadAvg < Probe
      def initialize(drift, data, opts = nil)
        super(drift, data, opts)
      end

      def get_value
        time = Time.now.to_f + @drift
        output = `cat /proc/loadavg`.split(' ')
        return [time, [output[0].to_f, output[1].to_f, output[2].to_f]]
      end
    end
  end
end
