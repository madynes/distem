
module Distem
  module Resource

      # Abstract representation of Network Latency resource
      class Latency < VIface::VTraffic::Property
        # The delay (String at 'tc' form such as "3ms")
        attr_reader :delay
        # Create a new Bandwidth
        # ==== Attributes
        # * +paramshash+ The Hash of the parameters to set (in the form "paramname" => value)
        #
        def initialize(paramshash={})
          super()
          @delay = nil
          parse_params(paramshash)
        end

        # Parameters parsing method
        def parse_params(paramshash)
          super(paramshash)
          @delay = paramshash['delay']
        end

        # adjust 'limit' parameter to netem so that it works sensibly
        # bandwidth is the rate that this link will emulate (in bytes/s)
        # it can be nil, then we assume it is 1Gbit/s
        def limit_from_bandwidth(bandwidth)
          bandwidth = (1024 ** 3) if bandwidth.nil?
          capacity = bandwidth * to_secs()
          # on average the packet has ~ 1500 bytes (Ethernet MTU?)
          packets = capacity / 1500.0
          # we give additional space (10%), just in case
          limit = (packets * 1.1).to_i
          limit = 1000 if limit < 1000
          return limit
        end

        def tc_params(bandwidth)
            return { 'delay' => @delay } if @delay.nil?
            return { 'delay' => @delay, 'limit' => limit_from_bandwidth(bandwidth) } 
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
