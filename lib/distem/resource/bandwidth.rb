
module Distem
  module Resource

      # Abstract representation of Network Bandwidth resource
      class Bandwidth < VIface::VTraffic::Property
        # The rate (String at 'tc' form such as "10mbps")
        attr_reader :rate

        # Create a new Bandwidth
        # ==== Attributes
        # * +paramshash+ The Hash of the parameters to set (in the form "paramname" => value)
        #
        def initialize(paramshash={})
          super()
          @rate = nil
          parse_params(paramshash)
        end

        # Parameters parsing method
        def parse_params(paramshash)
          super(paramshash)
          @rate = paramshash['rate'] if paramshash['rate']
        end

        # converts rate to integer number of bytes
        # returns nil if ArgumentError if the rate cannot be parsed
        def self.to_bytes(rate)
          return nil if rate.nil?
          m = /^(\d+)(\w*)$/.match(rate)
          raise ArgumentError if m.nil?
          digits, units = m.captures
          mult = case units
            when 'kbps' then 1024 # kilobytes
            when 'mbps' then (1024**2) # megabytes
            when 'kbit' then (1024 / 8) # kilobits
            when 'mbit' then (1024**2 / 8) # megabits
            when 'bps', '' then 1   # bytes
            else nil
          end
          raise ArgumentError if mult.nil?
          return (digits.to_i * mult)
        end

        def to_bytes
          Bandwidth.to_bytes(@rate)
        end

        def self.is_valid(rate)
            begin
              self.to_bytes(rate)
              return true
            rescue ArgumentError
              return false
            end
        end

      end

  end
end
