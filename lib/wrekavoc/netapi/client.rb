require 'rest_client'
require 'wrekavoc/netapi/netapi'

module Wrekavoc

  module NetAPI

    class Client
      def initialize(serveraddr,port=4567)
        raise unless port.is_a?(Numeric)
        # >>> TODO: validate server ip

        @resource = RestClient::Resource.new('http://' + serveraddr + ':' \
                                              + port.to_s)
      end

      def vnode_create(target, name)
        raise unless name.is_a?(String)
        raise if name.empty?
        # >>> TODO: validate target ip

        @resource[VNODE_CREATE].post :target => target, :name => name
      end
    end

  end

end
