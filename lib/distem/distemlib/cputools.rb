require 'distem'

module Distem
  module Lib

    # Class that allow to perform physical operations on a physical CPU resource
    class CPUTools
      # Set up a Resource::CPU resource to fit with the physical machine (node) properties
      # ==== Attributes
      # * +pcpu+ The CPU object
      #
      def self.set_resource(pcpu)
        raise InvalidParameterError, pcpu unless pcpu.is_a?(Resource::CPU)
        #str = File.read('/proc/cpuinfo')
        strhwloc = Shell.run('hwloc-ls --no-useless-caches')
        core = {}

        #Describe cores
        strhwloc.each_line do |line|
=begin
          if line =~ /processor\s*:\s*([0-9]+)\s*/
                  core['physicalid'] = Regexp.last_match(1)
          elsif line =~ /cpu MHz\s*:\s*([0-9]+\.?[0-9]*)\s*/
                  core['frequency'] = Regexp.last_match(1).to_f
          elsif line =~ /physical id\s*:\s([0-9]+)\s/
                  core['socketid'] = Regexp.last_match(1)
          elsif line =~ /core id\s*:\s([0-9]+)\s/
                  core['coreid'] = Regexp.last_match(1)
          end
=end
          if line =~ /\s*Core\s*#[0-9]+\s*\+\s*PU\s*#([0-9]+)\s*\(\s*phys\s*=\s*([0-9]+)\s*\)\s*/
          #/\s*Core\s*p#([0-9]+)\s*\+\s*PU\s*p#([0-9]+)\s*/
            core['physicalid'] = Regexp.last_match(2)
            core['coreid'] = Regexp.last_match(1)
            strcpufreq = Shell.run(
              "cat /sys/devices/system/cpu/cpu#{core['coreid']}/cpufreq/scaling_max_freq"
            )
            core['frequency'] = strcpufreq.strip.to_i
            strcpufreq = Shell.run(
              "cat /sys/devices/system/cpu/cpu#{core['coreid']}/cpufreq/scaling_available_frequencies"
            )
            core['frequencies'] = strcpufreq.strip.split.collect{ |val| val.to_i }
            core['frequencies'].sort!
          end

          if core['physicalid'] and core['coreid'] \
            and core['frequency'] and core['frequencies']
            pcpu.add_core(
              core['physicalid'],core['coreid'],
              core['frequency'],core['frequencies']
            )
            core = {}
          end
        end

        # Set cache links
        strhwloc = Shell.run('hwloc-ls -p --no-useless-caches')
        cur = []
        cache_links = false
        strhwloc.each_line do |line|
          if line =~ /\s*[A-Z][0-9]\s*\([0-9]+\s*[kKmMgGtT]?B\)\s*/
            cache_links = true
            pcpu.add_critical_cache_link(cur) unless cur.empty?
            cur = []
          elsif line =~ /\s*Core\s*p#[0-9]+\s*\+\s*PU\s*p#([0-9]+)\s*/
            cur << Regexp.last_match(1)
          end
        end
        pcpu.add_critical_cache_link(cur) if !cur.empty? and cache_links
      end
    end

  end
end
