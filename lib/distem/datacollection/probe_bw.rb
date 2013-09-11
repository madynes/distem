require 'thread'

module Distem
  module DataCollection
    class ProbeBW < Probe
      @last_tx = nil
      @last_rx = nil

      def initialize(drift, data, opts)
        super(drift, data, opts)
        @last_tx = 0
        @last_rx = 0
      end

      def get_value
        iface = @opts['interface']
        output = `cat /proc/net/dev`.split(/\n/).grep(/#{iface}/).first
        filter = output.gsub(iface,'').scan(/\d+/)
        rx = filter[0].to_i
        tx = filter[8].to_i
        if (@last_rx == 0)
          ret = nil
        else
          ret = [@frequency * (rx - @last_rx), @frequency * (tx - @last_tx)]
        end
        @last_rx = rx
        @last_tx = tx
        return ret
      end
    end
  end
end
