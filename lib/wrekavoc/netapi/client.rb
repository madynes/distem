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

      def vnode_start(target, vnode)
        # >>> TODO: validate target ip
        @resource[VNODE_START].post :target => target, :vnode => vnode
      end

      def vnode_stop(target, vnode)
        # >>> TODO: validate target ip
        @resource[VNODE_STOP].post :target => target, :vnode => vnode
      end

      def viface_create(target, vnode, name, ip)
        # >>> TODO: validate ips
        @resource[VIFACE_CREATE].post :target => target, :vnode => vnode, \
          :name => name, :ip => ip
      end

      def vnode_info_rootfs(target, vnode)
        # >>> TODO: validate ips
        @resource[VNODE_INFO_ROOTFS].post :target => target, :vnode => vnode
      end
    end

  end
end
