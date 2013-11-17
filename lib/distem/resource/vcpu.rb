
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
        # * +val+ Frequency or ration to set ti this VCore. If it is a frequency, it has to be specified in KHz, if it is a ratio, it as to be between 0 and 1 (taken as a percentage of the frequency of the future physical Core frequency that will be attached to this virtual core)
        # * +unit Tell if val is a frequency or a ratio
        def initialize(val,unit)
          @pcore = nil
          @frequency = nil
          @val = val
          @unit = unit
          @id = @@ids
          @@ids += 1
        end

        # Attach a physical core to this virtual one
        # ==== Attributes
        # * +pcore+ The Core object that describes the physical core to attach
        #
        def attach(pcore)
          @pcore = pcore
          update(@val,@unit)
        end

        def attached?
          return @pcore != nil
        end

        # Modify the frequency of this virtual one (to be used after attaching the vcore)
        # ==== Attributes
        # * +val+ The new value (frequency or ratio)
        # * +unit+ The way val is defined (mhz or ration values are allowed)
        def update(val,unit)
          val = val.to_f
          if attached?
            case unit
            when 'mhz'
              raise Lib::InvalidParameterError, val if val > @pcore.frequency or val <= 0
              @frequency = (val * 1000).to_i
            when 'ratio'
              @frequency = (@pcore.frequency * val).to_i
            else
              raise Lib::InvalidParameterError, unit
            end
          else
            @val = val
            @unit = unit
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
      # * +val+ The value to set on the virtual core, can be a frequency in mhz or a ratio
      # * +unit+ Tell if val is a frequency in MHz or if it is a ratio (allowed values are mhz or ratio)
      #
      def add_vcore(val,unit)
        vcore = VCore.new(val,unit)
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
      # * +val+ The value to set on the virtual cores, can be a frequency in mhz or a ratio
      # * +unit+ Tell if the val is a frequency in MHz or if it is a ratio (allowed values are mhz or ratio)
      #
      def update_vcores(val,unit)
        @vcores.each_value { |vcore| vcore.update(val,unit) }
      end
    end

  end
end

