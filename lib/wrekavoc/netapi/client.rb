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

      def viface_create(vnode, name)
        @resource[VIFACE_CREATE].post :vnode => vnode, :name => name
      end

      def vnode_gateway(vnode)
        @resource[VNODE_GATEWAY].post :vnode => vnode
      end

      def vnode_info_rootfs(vnode)
        @resource[VNODE_INFO_ROOTFS].post :vnode => vnode
      end

      def vnode_info_pnode(vnode)
        @resource[VNODE_INFO_PNODE].post :vnode => vnode
      end

      def vnode_info_list(target)
        @resource[VNODE_INFO_LIST].post :target => target
      end

      def vnetwork_create(name, address)
        # >>> TODO: validate ips
        @resource[VNETWORK_CREATE].post :name => name, :address => address
      end

      def vnetwork_add_vnode(vnetwork, vnode, viface)
        # >>> TODO: validate ips
        @resource[VNETWORK_ADD_VNODE].post :vnetwork => vnetwork, \
          :vnode => vnode, :viface => viface
      end

      def viface_attach(vnode, viface, address)
        # >>> TODO: validate ips
        @resource[VIFACE_ATTACH].post :vnode => vnode, :viface => viface, \
          :address => address
      end

      def vroute_create(srcnet,destnet,gateway,vnode="")
        @resource[VROUTE_CREATE].post :networksrc => srcnet, \
          :networkdst => destnet, :gatewaynode => gateway, :vnode => vnode
      end

      def vroute_complete()
        @resource[VROUTE_COMPLETE].post ""
      end

      def vnode_execute(vnode, command)
        # >>> TODO: validate ips
        @resource[VNODE_EXECUTE].post :vnode => vnode, :command => command
      end

      def limit_net_create(vnode,viface,direction,properties)
        @resource[LIMIT_NET_CREATE].post :vnode => vnode, :viface => viface, \
          :direction => direction, :properties => properties
      end
    end

  end
end
