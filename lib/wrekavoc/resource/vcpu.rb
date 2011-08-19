require 'wrekavoc'

module Wrekavoc
  module Resource

    class VCPU
      class VCore
        attr_reader :pcore,:frequency
        def initialize(pcore,freq)
          raise Lib::InvalidParameterError, freq \
            if freq > pcore.frequency or freq <= 0
          @pcore = pcore

          if freq > 0 and freq <= 1
            @frequency = (pcore.frequency * freq).to_i
          else
            @frequency = freq.to_i
          end
        end
      end

      attr_reader :vcores,:pcpu
      def initialize(pcpu)
        @pcpu = pcpu
        @vcores = {}
      end

      def add_vcore(pcore,freq)
        @vcores[pcore] = VCore.new(pcore,freq)
      end

      def get_vcore(pcore)
        return @vcores[pcore]
      end

      def remove_vcore(pcore)
        @vcores.delete(pcore)
      end
    end

  end
end

