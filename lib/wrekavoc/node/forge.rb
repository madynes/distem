require 'wrekavoc'

module Wrekavoc
  module Node

    class Forge
      def initialize(resource,algorithm)
        @resource = resource
        raise Lib::InvalidParameterError, algorithm \
          unless algorithm.is_a?(Algorithm::Algorithm)
        @algorithm = algorithm
      end

      def apply()
        @algorithm.apply(@resource)
      end

      def undo()
        @algorithm.undo(@resource)
      end
    end
  end
end

