require 'wrekavoc'
require 'rest_client'

module Wrekavoc
  module NetAPI

    class Client
      def initialize(serveraddr,port=4567)
        raise unless port.is_a?(Numeric)
        # >>> TODO: validate server ip

        @serveraddr = serveraddr
        @resource = RestClient::Resource.new('http://' + @serveraddr + ':' \
                                              + port.to_s)
      end

      def pnode_init(target)
        @resource[PNODE_INIT].post :target => target
      end

      def vnode_create(target, name, image)
        # >>> TODO: validate target ip

        @resource[VNODE_CREATE].post :target => target, :name => name, \
          :image => image
      end

      def vnode_start(vnode)
        @resource[VNODE_START].post :vnode => vnode
      end

      def vnode_stop(vnode)
        @resource[VNODE_STOP].post :vnode => vnode
      end

      def viface_create(vnode, name, ip)
        # >>> TODO: validate ips
        @resource[VIFACE_CREATE].post :vnode => vnode, :name => name, :ip => ip
      end

      def vnode_info_rootfs(vnode)
        # >>> TODO: validate ips
        @resource[VNODE_INFO_ROOTFS].post :vnode => vnode
      end
    end

  end
end
