require 'wrekavoc'

module Wrekavoc
  module Resource

    class Status
      INIT='INIT'
      CONFIGURING='CONFIGURING'
      READY='READY'
      RUNNING="RUNNING"
      def self.valid?(status)
        return [INIT,CONFIGURING,READY,RUNNING].include?(status.upcase)
      end
    end

  end
end
