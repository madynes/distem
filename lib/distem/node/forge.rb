#require 'distem'

module Distem
  module Node

    # Interfaced used to "blacksmith" resources: apply a specify algorithm to a physical resource in order to modify it to fit with the virtual resources specifications
    class Forge
      # The resource to "blacksmith"
      attr_reader :resource
      # The algorithm used to "blacksmith" the resource
      attr_reader :algorithm

      # Create a new Forge specifying the resource to modify and the algorithm to use
      # ==== Attributes
      # * +resource+ The Resource object
      # * +algorithm+ The Algorithm object
      #
      def initialize(resource,algorithm)
        @resource = resource
        raise Lib::InvalidParameterError, algorithm if \
          algorithm and !algorithm.is_a?(Algorithm::Algorithm)
        @algorithm = algorithm
      end

      # Apply the algorithm on the physical resource
      def apply()
        @algorithm.apply(@resource)
      end

      # Undo the algorithm on the physical resource
      def undo()
        @algorithm.undo(@resource)
      end
    end
  end
end

