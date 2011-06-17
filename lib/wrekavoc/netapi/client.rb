require 'wrekavoc'
require 'rest_client'
require 'json'
require 'pp'

module Wrekavoc
  module NetAPI

    class Client
      HTTP_STATUS_OK = 200

      def initialize(serveraddr,port=4567)
        raise unless port.is_a?(Numeric)
        # >>> TODO: validate server ip

        @serveraddr = serveraddr
        @resource = RestClient::Resource.new('http://' + @serveraddr + ':' \
          + port.to_s)
      end

      def pnode_init(target = NetAPI::TARGET_SELF)
        ret = {}
        @resource[PNODE_INIT].post(
          {:target => target}
        ) { |response, request, result|
          ret = JSON.parse(check_error(result,response))
        }
        return ret
      end

      def vnode_create(name, properties)
        properties = properties.to_json if properties.is_a?(Hash)

        ret = {}
        @resource[VNODE_CREATE].post(
          { :name => name , :properties => properties }
        ) { |response, request, result|
          ret = JSON.parse(check_error(result,response))
        }
        return ret
      end

      def vnode_start(vnode)
        ret = {}
        @resource[VNODE_START].post(
          { :vnode => vnode }
        ) { |response, request, result|
          ret = JSON.parse(check_error(result,response))
        }
        return ret
      end

      def vnode_stop(vnode)
        ret = {}
        @resource[VNODE_STOP].post(
          { :vnode => vnode }
        ) { |response, request, result|
          ret = JSON.parse(check_error(result,response))
        }
        return ret
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

      def vnode_info_list()
        @resource[VNODE_INFO_LIST].get
      end

      def vnode_info(vnodename)
        @resource[VNODE_INFO + '/' + vnodename].get
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

      def limit_net_create(vnode,viface,properties)
        properties = properties.to_json if properties.is_a?(Hash)
        @resource[LIMIT_NET_CREATE].post :vnode => vnode, :viface => viface, \
          :properties => properties
      end

      protected

      def check_error(result,response)
        case result.code.to_i
          when HTTP_STATUS_OK
          else
            raise Lib::ClientError.new(
              result.code.to_i, \
              response.headers[:x_application_error_code], \
              JSON.parse(response) \
            )
        end
        return response
      end
    end

  end
end
