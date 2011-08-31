require 'wrekavoc'

module Wrekavoc
  module Resource

    # Abstract representation of a virtual CPU resource
    class VCPU
      # Abstract representation of a virtual Core resource
      class VCore
        @@ids = 0
        # The (unique) id of this virtual resource
        attr_reader :id
        # The physical Core associated to this virtual resource
        attr_reader :pcore
        # The frequency to be set to this physical resource (KHz)
        attr_reader :frequency

        # Create a new VCore
        # ==== Attributes
        # * +freq+ The frequency to set to this VCore. If between 0 and 1, taken as a percentage of the frequency of the future physical Core frequency that will be attached to this virtual core, otherwise the frequency in KHz.
        #
        def initialize(freq)
          @pcore = nil
          @frequency = freq
          @id = @@ids
          @@ids += 1
        end

        # Attach a physical core to this virtual one
        # ==== Attributes
        # * +pcore+ The Core object that describes the physical core to attach
        #
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

      # The physical CPU associated to this virtual one
      attr_reader :pcpu
      # Hash describing the associated virtual cores (key: VCore.id, val: VCore)
      attr_reader :vcores

      # Create a new VCPU
      # ==== Attributes
      # * +pcpu+ The physical CPU to associate to this virtual one
      #
      def initialize(pcpu)
        @pcpu = pcpu
        @vcores = {}
      end

      # Adds a new virtual core to this virtual CPU
      # ==== Attributes
      # * +freq+ The frequency to set to this new virtual core
      #
      def add_vcore(freq)
        vcore = VCore.new(freq)
        @vcores[vcore.id] = vcore
      end

      # Gets a VCore specifying it's id
      # ==== Attributes
      # * +id+ The ID (VCore.id) of the VCore to return
      # ==== Returns
      # VCore object
      #
      def get_vcore(id)
        return @vcores[id]
      end

      # Remove a VCore from this VCPU
      # ==== Attributes
      # * +id+ The if of the VCore to remove
      #
      def remove_vcore(id)
        @vcores.delete(id)
      end
    end

  end
end

