
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
        @mem = @swap = @hard_limit = @soft_limit = nil
        set(opts) if opts
      end

      # Set memory to a Vnode
      def set(opts)
        @hierarchy = opts['hierarchy'] if opts['hierarchy']
        @mem = opts['mem'] if opts['mem']
        @swap = opts['swap'] if opts['swap']
        @hard_limit = opts['hard_limit'] if opts['hard_limit']
        @soft_limit = opts['soft_limit'] if opts['soft_limit']
        if @hierarchy == 'v2'
          @mem = [@hard_limit, @soft_limit].reject{|v| v == 'max'}.compact.min
          @mem = 'max' if @mem.nil? && [@hard_limit, @soft_limit].include?('max')
        end
      end

      def remove
        @mem = @swap = @hard_limit = @soft_limit = nil
      end
    end
  end
end

