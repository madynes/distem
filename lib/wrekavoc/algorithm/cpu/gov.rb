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
          if vnode.vcpu and vnode.vcpu.vcores
            vnode.vcpu.vcores.each_value do |vcore|
              freqmax = vcore.pcore.frequency unless freqmax
              freqs = vcore.pcore.frequencies
              wfreq = vcore.frequency unless wfreq
              hfreq = freqs.select{|val| val >= wfreq}[0] unless hfreq
              if hfreq == freqs[0]
                lfreq = 0 unless lfreq
              else
                lfreq = freqs.index(hfreq) - 1 unless lfreq
              end
                
              cores << vcore.pcore.physicalid.to_i
            end
          end

          unless cores.empty?
            @ext = CPUExtension::CPUGov.new(
              cores,freqmax,"#{Node::Admin::PATH_CGROUP}/#{vnode.name}"
            )
            ratio = (wfreq.to_f - hfreq) / (lfreq - hfreq)
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

