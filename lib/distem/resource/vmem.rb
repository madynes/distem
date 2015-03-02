
module Distem
  module Resource

    # Abstract representation of a virtual memory resource
    class VMem
      # Max memory
      attr_reader :mem
      # Max swap memory
      attr_reader :swap

      # Create a new VMem
      #
      def initialize(opts = nil)
        @mem = @swap = nil
        set(opts) if opts
      end

      # Set memory to a Vnode
      def set(opts)
        @mem = opts['mem'].to_i if opts['mem']
        @swap = opts['swap'].to_i if opts['swap']
      end

      def remove
        @mem = @swap = nil
      end
    end
  end
end

