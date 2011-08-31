module Distem
  # A module containing classes that allow to apply different kind of limitations on physical resources
  module Algorithm

    # Interface that give the way Algorithms should work
    class Algorithm
      def initialize()
      end

      # Apply the algorithm on a resource
      def apply(resource)
        undo(resource)
      end

      # Undo the algorithm on a resource
      def undo(resource)
      end
    end
  end
end
