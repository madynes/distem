
module Distem
  module Algorithm 
    module CPU

      # Algorithm based on CPU burning methods. A process is launched in background and consume 100-wished_% percent of the core calculation resources i.e. if the cpu have to be set at 80% of this performancy, the algorithm will consume 20% permanently
      class Hogs < Algorithm
        # Create a new Hogs object
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
          coresdesc = {}

          if vnode.vcpu and vnode.vcpu.vcores
            vnode.vcpu.vcores.each_value do |vcore|
              coresdesc[vcore.pcore.physicalid.to_i] = 
                vcore.frequency.to_f / vcore.pcore.frequency.to_f if \
                vcore.frequency < vcore.pcore.frequency
            end
          end

          unless coresdesc.empty?
            @ext = CPUExtension::CPUHogs.new
            @ext.run(coresdesc)
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
