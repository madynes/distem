require 'wrekavoc'

module Wrekavoc
  module Node

    class NetworkLimitation
      def self.apply(limitation)
        TCWrapper::TCConfig.perform_config_tbf(limitation.vnode,limitation.viface,[limitation])
        # >>> TODO: Apply the TC commands
      end
    end

  end
end
