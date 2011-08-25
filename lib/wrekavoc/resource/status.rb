require 'wrekavoc'

module Wrekavoc
  module Resource

    # Abstract representation of the status a resource can be in
    class Status
      # The resource just finished to initialize
      INIT='INIT'
      # The resource is configuring/busy
      CONFIGURING='CONFIGURING'
      # The resource is ready to use/run
      READY='READY'
      # The resource is currently running
      RUNNING="RUNNING"

      # Returns if a status name is valid or not
      # ==== Attributes
      # * +status+ The String value to test
      # ==== Returns
      # Boolean value
      #
      def self.valid?(status)
        return [INIT,CONFIGURING,READY,RUNNING].include?(status.upcase)
      end
    end

  end
end
