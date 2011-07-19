require 'wrekavoc'

module Wrekavoc
  module Lib

    class MemoryTools
      def self.set_resource(pmem)
        str = File.read('/proc/meminfo')
        mem = {}
        str.each_line do |line|
          if line =~ /MemTotal\s*:\s*([0-9]+)\s*kB\s*/
            mem['capacity'] = Regexp.last_match(1).to_i / 1024
          elsif line =~ /SwapTotal\s*:\s*([0-9]+)\s*kB\s*/
            mem['swap'] = Regexp.last_match(1).to_i / 1024
          end
          if mem['capacity'] and mem['swap']
            pmem.capacity = mem['capacity']
            pmem.swap = mem['swap']
            break
          end
        end
      end
    end

  end
end

