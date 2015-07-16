
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
        strhwloc = Shell.run('hwloc-ls --no-useless-caches')
        core = {}

        #Describe cores
        #hwloc 1.0.2 (Debian Squeeze)
        pattern1 = /\s*Core\s*#[0-9]+\s*\+\s*PU\s*#([0-9]+)\s*\(\s*phys\s*=\s*([0-9]+)\s*\)\s*/
        #hwloc 1.4.1 (Debian Wheezy)
        pattern2 = /\s*Core\s*L#[0-9]+\s*\+\s*PU\s*L#([0-9]+)\s*\(P#([0-9]+)\)\s*/
        strhwloc.each_line do |line|
          if (line =~ pattern1) || (line =~ pattern2)
          #/\s*Core\s*p#([0-9]+)\s*\+\s*PU\s*p#([0-9]+)\s*/
            core['physicalid'] = Regexp.last_match(2)
            core['coreid'] = Regexp.last_match(1)
            if File.exist?("/sys/devices/system/cpu/cpu#{core['coreid']}/cpufreq") &&
               !File.exist?("/sys/devices/system/cpu/intel_pstate")
              strcpufreq = Shell.run(
                "cat /sys/devices/system/cpu/cpu#{core['coreid']}/cpufreq/scaling_max_freq"
              )
              core['frequency'] = strcpufreq.strip.to_i
              strcpufreq = Shell.run(
                "cat /sys/devices/system/cpu/cpu#{core['coreid']}/cpufreq/scaling_available_frequencies"
              )
              core['frequencies'] = strcpufreq.strip.split.collect{ |val| val.to_i }
              core['frequencies'].sort!
            else
              core['frequency'] = 1000000
              core['frequencies'] = [ 1000000 ]
            end
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
        #hwloc 1.0.2 (Debian Squeeze)
        pattern1 = /\s*Core\s*p#[0-9]+\s*\+\s*PU\s*p#([0-9]+)\s*/
        #hwloc 1.4.1 (Debian Wheezy)
        pattern2 = /\s*Core\s*P#[0-9]+\s*\+\s*PU\s*P#([0-9]+)\s*/
        strhwloc = Shell.run('hwloc-ls -p --no-useless-caches')
        cur = []
        cache_links = false
        strhwloc.each_line do |line|
          if line =~ /\s*L[0-9]\s*\([0-9]+\s*[kKmMgGtT]?B\)\s*/
            cache_links = true
            pcpu.add_critical_cache_link(cur) unless cur.empty?
            cur = []
          elsif (line =~ pattern1) || (line =~ pattern2)
            cur << Regexp.last_match(1)
          end
        end
        pcpu.add_critical_cache_link(cur) if !cur.empty? and cache_links
      end
    end

  end
end
