require 'pp'
module Distem
  module Algorithm 
    module CPU

      # Algorithm based on CPU throttling methods (see http://en.wikipedia.org/wiki/Dynamic_frequency_scaling). A core is changing his frequency periodatically between two values to reach the wished one i.e. if our physical core can change it's frequency to 1.5GHz, 2.0GHz and 2.5GHz and we want it to be set at 2.3GHz, this algorithm will make the core work 40% of the time at 2GHz and 60% at 2.5GHz.
      class Gov < Algorithm
        # Create a new Gov object
        def initialize()
          super()
          @ext = nil
        end

        # Apply the algorithm on a resource (virtual node)
        # ==== Attributes
        # * +vnode+ The VNode object
        #
        def apply(vnode)
          super(vnode)
          cores = []
          freqmax = nil
          lfreq = nil
          hfreq = nil
          wfreq = nil # wished frequency
          ratio = nil
          if vnode.vcpu and vnode.vcpu.vcores
            #check available frequencies table
            pcores = vnode.host.cpu.get_allocated_cores(vnode)
            cores = pcores.collect{ |core| core.physicalid.to_i }
            vcore = vnode.vcpu.vcores[vnode.vcpu.vcores.keys[0]]
            freqs = vcore.pcore.frequencies
            freqs.sort
            freqmax = vcore.pcore.frequency
            wfreq = vcore.frequency.to_i
            # if the wished frequency is one of the cpu possible frequency
            if freqs.index(wfreq)
              lfreq = wfreq
              hfreq = wfreq
              ratio = 1.0
            else
              hfreq = freqs.select{|val| val >= wfreq}[0]
              if hfreq == freqs[0]
                lfreq = 0 
              else
                lfreq = freqs[freqs.index(hfreq) - 1]
              end
            end
          end

          unless cores.empty?
            @ext = CPUExtension::CPUGov.new(
              cores,freqmax,"#{Node::Admin::PATH_CGROUP}/#{vnode.name}"
            )
            ratio = (wfreq.to_f - hfreq) / (lfreq - hfreq) unless ratio
            @ext.run(lfreq.to_i,hfreq.to_i,ratio.to_f)
          end
        end

        # Undo the algorithm on a resource (virtual node)
        # ==== Attributes
        # * +vnode+ The VNode object
        #
        def undo(vnode)
          super(vnode)
          if @ext
            @ext.stop
            @ext = nil
          end
        end
      end

    end
  end
end

