require 'wrekavoc'
require 'ext/cpuhogs'

module Wrekavoc
  module Algorithm 
    module CPU

      class Hogs < Algorithm
        def initialize()
          super()
          @ext = nil
        end

        def apply(vnode)
          super(vnode)
          coresdesc = {}

          if vnode.vcpu and vnode.vcpu.vcores
            vnode.vcpu.vcores.each_value do |vcore|
              coresdesc[vcore.pcore.physicalid.to_i] = vcore.frequency / vcore.pcore.frequency if vcore.frequency < vcore.pcore.frequency
            end
          end

          unless coresdesc.empty?
            @ext = CPUExtension::CPUHogs.new
            @ext.run(coresdesc)
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
