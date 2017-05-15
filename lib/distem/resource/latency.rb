
module Distem
  module Resource

      # Abstract representation of Network Latency resource
      class Latency < VIface::VTraffic::Property
        # The delay (String at 'tc' form such as "3ms")
        attr_reader :delay
        attr_reader :jitter
        # Create a new Bandwidth
        # ==== Attributes
        # * +paramshash+ The Hash of the parameters to set (in the form "paramname" => value)
        #
        def initialize(paramshash={})
          super()
          @delay = nil
          @jitter = nil
          parse_params(paramshash)
        end

        # Parameters parsing method
        def parse_params(paramshash)
          super(paramshash)
          @delay = paramshash['delay']
          @jitter = paramshash['jitter']
        end

        # converts the latency/delay to seconds (floating point)
        # returns nil if not set
        def self.to_secs(delay)
          return nil if delay.nil?
          m = /^(\d+)(\w*)$/.match(delay)
          raise ArgumentError if m.nil?
          digits, units = m.captures
          mult = case units
            when 's', 'sec', 'secs' then 1.0 # seconds
            when 'ms', 'msec', 'msecs' then 0.001 # milliseconds
            when 'us', 'usec', 'usecs', '' then 0.000001 # microseconds
            else nil
          end
          raise ArgumentError if mult.nil?
          return (digits.to_i * mult)
        end

        def to_secs
          Latency.to_secs(@delay)
        end

        def self.is_valid(latency)
          begin
            self.to_secs(latency)
            return true
          rescue ArgumentError
            return false
          end
        end

      end
  end
end
