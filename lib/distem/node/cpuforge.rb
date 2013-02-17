#require 'distem'

module Distem
  module Node

    # Allows to modify CPU physical resources to fit with the virtual resources specifications
    class CPUForge < Forge
      # Create a new CPUForge specifying the virtual node resource to modify (limit) and the algorithm to use
      # ==== Attributes
      # * +vnode+ The VNode object
      # * +algorithm+ The Algorithm::CPU object
      #
      def initialize(vnode, algorithm=Algorithm::CPU::HOGS)
        #raise unless algorithm.is_a?(Algorithm::CPU)
        
        case algorithm.upcase
          when Algorithm::CPU::GOV.upcase
            algorithm = Algorithm::CPU::Gov.new
          when Algorithm::CPU::HOGS.upcase
            algorithm = Algorithm::CPU::Hogs.new
          else
            algorithm = Algorithm::CPU::Hogs.new
        end

        super(vnode,algorithm)
      end
    end

  end
end
