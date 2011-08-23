require 'wrekavoc'
require 'ext/cpugov'

module Wrekavoc
  module Algorithm 
    module CPU

      class Gov < Algorithm
        def initialize()
          super()
          @ext = nil
        end

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

            vcore = vnode.vcpu.vcores[0]
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

        def undo(vnode)
          super(vnode)
          @ext.stop if @ext
        end
      end

    end
  end
end

