require 'wrekavoc'

module Wrekavoc
  module Node

  class CPULimitation
      def initialize(vnode,algorithm=nil)
        @vnode = vnode
        if algorithm
          @algorithm = algorithm
        else
          @algorithm = Limitation::CPU::HogsAlgorithm.new
        end
      end

      def apply()
        @algorithm.apply(@vnode.vcpu)
      end

      def undo()
        @algorithm.undo
      end
    end

  end
end
