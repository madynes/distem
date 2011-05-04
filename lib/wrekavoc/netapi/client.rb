require 'wrekavoc'
require 'rest_client'

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
        # >>> TODO: validate target ip

        @resource[VNODE_CREATE].post :target => target, :name => name, \
          :image => image
      end

      def viface_create(target, vnode, name, ip)
        # >>> TODO: validate ips
        @resource[VIFACE_CREATE].post :target => target, :vnode => vnode, \
          :name => name, :ip => ip
      end
    end

  end
end
