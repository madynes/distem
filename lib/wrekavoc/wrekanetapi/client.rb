require 'rest_client'
require 'netapi'

module Wrekavoc

  module NetAPI

    class Client
      def initialize(serveraddr,port=4567)
        raise unless port.is_a?(Numeric)
        # >>> TODO: validate server ip

        @ressource = RestClient::Resource.new('http://' + serveraddr + ':' \
                                              + port.to_s)
      end

      def vnode_create(target, name)
        raise unless name.is_a?(String)
        raise if name.empty?
        # >>> TODO: validate target ip

        @ressource[VNODE_CREATE].post :target => target, :name => name
      end
    end

  end

end
