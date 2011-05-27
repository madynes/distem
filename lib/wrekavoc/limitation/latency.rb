require 'wrekavoc'

module Wrekavoc
  module Limitation

    class Latency < Network
      attr_reader :delay
      def initialize(vnode, viface, direction, delay)
        super(vnode, viface, direction)
        @delay = delay
      end
    end

  end
end

