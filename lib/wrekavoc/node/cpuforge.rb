require 'wrekavoc'

module Wrekavoc
  module Node

  class CPUForge < Forge
      def initialize(vnode, algorithm=Algorithm::CPU::Gov.new)
        super(vnode,algorithm)
      end
    end

  end
end
