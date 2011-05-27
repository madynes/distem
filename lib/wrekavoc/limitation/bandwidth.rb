require 'wrekavoc'

module Wrekavoc
  module Limitation

    class Bandwidth < Network
      attr_reader :rate
      def initialize(vnode, viface, direction, rate)
        super(vnode, viface, direction)
        @rate = rate
      end
    end

  end
end
