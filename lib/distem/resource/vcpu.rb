require 'distem'

module Distem
  module Resource

    # Abstract representation of a virtual CPU resource
    class VCPU
      # Abstract representation of a virtual Core resource
      class VCore
        @@ids = 0
        # The (unique) id of this virtual resource
        attr_reader :id
        # The physical Core associated to this virtual resource
        attr_accessor :pcore
        # The frequency to be set to this physical resource (KHz)
        attr_accessor :frequency

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
          @pcore = pcore
          update(@frequency)
        end

        def attached?
          return @pcore != nil
        end

        # Modify the frequency of this virtual one (to be used after attaching the vcore)
        # ==== Attributes
        # * +freq+ The new frequemcy
        def update(freq)
          if attached?
            raise Lib::InvalidParameterError, @frequency if \
              @frequency > @pcore.frequency or @frequency <= 0

            if @frequency > 0 and @frequency <= 1
              @frequency = (@pcore.frequency * @frequency).to_i
            else
              @frequency = @frequency.to_i
            end
          else
            @frequency = freq
          end
        end
      end

      # The physical CPU associated to this virtual one
      attr_accessor :pcpu
      # Hash describing the associated virtual cores (key: VCore.id, val: VCore)
      attr_reader :vcores

      # Create a new VCPU
      #
      def initialize(vnode)
        @vcores = {}
        @vnode = vnode
        @pcpu = nil
      end

      # Attach a physical cpu to this virtual one
      def attach
        raise Lib::UninitializedResourceError 'vnode.host' unless @vnode.host
        @pcpu = @vnode.host.cpu

        cores = @pcpu.alloc_cores(@vnode,@vcores.size,
          (@vnode.host.algorithms[:cpu] == Algorithm::CPU::GOV)
        )

        i = 0
        @vcores.each_value do |vcore|
          vcore.attach(cores[i])
          i += 1
        end
      end

      def attached?
        return @pcpu != nil
      end

      def detach
        @pcpu.free_cores(@vnode) if @pcpu
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

      # Update every virtual cores of this virtual CPU
      # ==== Attributes
      # * +freq+ The new frequency to set on the virtual cores
      #
      def update_vcores(freq)
        @vcores.each_value { |vcore| vcore.update(freq) }
      end
    end

  end
end

