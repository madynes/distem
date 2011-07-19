require 'wrekavoc'

module Wrekavoc
  module Lib

    class CPUTools
      def self.set_resource(pcpu)
        raise InvalidParameterError, pcpu unless pcpu.is_a?(Resource::CPU)
        str = File.read('/proc/cpuinfo')
        core = {}

        #Describe cores
        str.each_line do |line|
          if line =~ /processor\s*:\s*([0-9]+)\s*/
                  core['physicalid'] = Regexp.last_match(1)
          elsif line =~ /cpu MHz\s*:\s*([0-9]+\.?[0-9]*)\s*/
                  core['frequency'] = Regexp.last_match(1).to_f
=begin
          elsif line =~ /physical id\s*:\s([0-9]+)\s/
                  core['socketid'] = Regexp.last_match(1)
          elsif line =~ /core id\s*:\s([0-9]+)\s/
                  core['coreid'] = Regexp.last_match(1)
=end
          end

          if core['physicalid'] and core['frequency']
            pcpu.add_core(core['physicalid'],core['frequency'])
            core = {}
          end
        end

        # Set cache links
        str = Shell.run('hwloc-ls -p --no-useless-caches')
        cur = []
        str.each_line do |line|
          if line =~ /\s*[A-Z][0-9]\s*\([0-9]+\s*[kKmMgGtT]?B\)\s*/
            pcpu.add_critical_cache_link(cur) unless cur.empty?
            cur = []
          elsif line =~ /\s*Core\s*p#[0-9]+\s*\+\s*PU\s*p#([0-9]+)\s*/
            coreid = Regexp.last_match(1)
            cur << pcpu.get_core(coreid)
          end
        end
        pcpu.add_critical_cache_link(cur) unless cur.empty?
      end
    end

  end
end
