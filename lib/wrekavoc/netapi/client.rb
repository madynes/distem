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

      def pnode_init(target)
        # >>> TODO: validate target ip

        @resource[PNODE_INIT].post :target => target
      end

      def vnode_create(target, name, image)
        raise unless name.is_a?(String)
        raise if name.empty?
        # >>> TODO: validate target ip

        @resource[VNODE_CREATE].post :target => target, :name => name, \
          :image => image
      end
    end

  end

end
