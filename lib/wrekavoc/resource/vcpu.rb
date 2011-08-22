require 'wrekavoc'

module Wrekavoc
  module Resource

    class VCPU
      class VCore
        @@ids = 0
        attr_reader :pcore,:frequency,:id
        def initialize(freq)
          @pcore = nil
          @frequency = freq
          @id = @@ids
          @@ids += 1
        end

        def attach(pcore)
          raise Lib::InvalidParameterError, @frequency \
            if @frequency > pcore.frequency or @frequency <= 0
          @pcore = pcore
          if @frequency > 0 and @frequency <= 1
            @frequency = (pcore.frequency * @frequency).to_i
          else
            @frequency = @frequency.to_i
          end
        end
      end

      attr_reader :vcores,:pcpu
      def initialize(pcpu)
        @pcpu = pcpu
        @vcores = {}
      end

      def add_vcore(freq)
        vcore = VCore.new(freq)
        @vcores[vcore.id] = vcore
      end

      def get_vcore(id)
        return @vcores[id]
      end

      def remove_vcore(id)
        @vcores.delete(id)
      end
    end

  end
end

