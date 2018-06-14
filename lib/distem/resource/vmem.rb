
module Distem
  module Resource

    # Abstract representation of a virtual memory resource
    class VMem
      attr_reader :hierarchy
      # Max memory (cg1)
      attr_reader :mem
      # Max swap memory (cg1/cg2)
      attr_reader :swap
      # Hard limit (cg2)
      attr_reader :hard_limit
      # Soft limit (cg2)
      attr_reader :soft_limit

      # Create a new VMem
      #
      def initialize(opts = nil)
        @hierarchy = 'v1'
        @mem = @swap = @hard_limit = @soft_limit = nil
        set(opts) if opts
      end

      # Set memory to a Vnode
      def set(opts)
        @hierarchy = opts['hierarchy'] if opts['hierarchy']
        @mem = opts['mem'].to_i if opts['mem']
        @swap = opts['swap'].to_i if opts['swap']
        @hard_limit = opts['hard_limit'].to_i if opts['hard_limit']
        @soft_limit = opts['soft_limit'].to_i if opts['soft_limit']
        @mem = [vnode.vmem.hard_limit, vnode.vmem.soft_limit].compact.min if @hierarchy == 'v2'
      end

      def remove
        @mem = @swap = @hard_limit = @soft_limit = nil
      end
    end
  end
end

