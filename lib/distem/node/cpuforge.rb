require 'wrekavoc'

module Wrekavoc
  module Node

    # Allows to modify CPU physical resources to fit with the virtual resources specifications
    class CPUForge < Forge
      # Create a new CPUForge specifying the virtual node resource to modify (limit) and the algorithm to use
      # ==== Attributes
      # * +vnode+ The VNode object
      # * +algorithm+ The Algorithm::CPU object
      #
      def initialize(vnode, algorithm=Algorithm::CPU::Gov.new)
        #raise unless algorithm.is_a?(Algorithm::CPU)
        super(vnode,algorithm)
      end
    end

  end
end
