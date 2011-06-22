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
        @serveraddr = serveraddr
        @serverurl = 'http://' + @serveraddr + ':' + port.to_s
        @resource = RestClient::Resource.new(@serverurl)
      end

      def pnode_init(target = NetAPI::TARGET_SELF)
        begin
          ret = {}
          req = "/pnodes"
          @resource[req].post(
            {:target => target}
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def pnode_info(pnodename)
        begin
          ret = {}
          req = "/pnodes/#{pnodename}"
          @resource[req].get { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def vnode_create(name, properties)
        begin
          properties = properties.to_json if properties.is_a?(Hash)

          ret = {}
          req = '/vnodes'
          @resource[req].post(
            { :name => name , :properties => properties }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def vnode_info(vnodename)
        begin
          ret = {}
          req = "/vnodes/#{vnodename}"
          @resource[req].get { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def vnode_start(vnode)
        begin
          ret = {}
          req = "/vnodes/#{vnode}"
          @resource[req].put(
            { :status => Resource::VNode::Status::RUNNING }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def vnode_stop(vnode)
        begin
          ret = {}
          req = "/vnodes/#{vnode}"
          @resource[req].put(
            { :status => Resource::VNode::Status::STOPPED }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def viface_create(vnode, name)
        begin
          ret = {}
          req = "/vnodes/#{vnode}/vifaces"
          @resource[req].post(
            { :name => name }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def vnode_gateway(vnode)
        begin
          ret = {}
          req = "/vnodes/#{vnode}/mode"
          @resource[req].put(
            { :mode => Resource::VNode::MODE_GATEWAY }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def vnode_info_rootfs(vnode)
        @resource['/vnodes/infos/rootfs'].post :vnode => vnode
      end

      def vnode_info_list()
        begin
          ret = {}
          req = "/vnodes"
          @resource[req].get({}) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def vnetwork_create(name, address)
        begin
          ret = {}
          req = "/vnetworks"
          @resource[req].post(
            { :name => name, :address => address }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def vnetwork_info(vnetworkname)
        begin
          ret = {}
          req = "/vnetworks/#{vnetworkname}"
          @resource[req].get { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def viface_attach(vnode, viface, properties)
        begin
          properties = properties.to_json if properties.is_a?(Hash)
          ret = {}
          req = "/vnodes/#{vnode}/vifaces/#{viface}"
          @resource[req].put(
            { :properties => properties }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def vroute_create(srcnet,destnet,gateway,vnode="")
        begin
          ret = {}
          req = "/vnetworks/vroutes"
          @resource[req].post(
            { :networksrc => srcnet, :networkdst => destnet,
               :gatewaynode => gateway, :vnode => vnode }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def vroute_complete()
        begin
          ret = {}
          req = "/vnetworks/vroutes/complete"
          @resource[req].post({}) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def vnode_execute(vnode, command)
        begin
          ret = {}
          req = "/vnodes/#{vnode}/commands"
          @resource[req].post(
            { :command => command }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      def limit_net_create(vnode,viface,properties)
        properties = properties.to_json if properties.is_a?(Hash)
        begin
          ret = {}
          req = "/limitations/network"
          @resource[req].post(
            { :vnode => vnode, :viface => viface, :properties => properties }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      protected

      def check_error(result,response)
        case result.code.to_i
          when HTTP_STATUS_OK
          else
            begin
              body = JSON.parse(response)
            rescue JSON::ParserError
              body = response
            end

            raise Lib::ClientError.new(
              result.code.to_i,
              response.headers[:x_application_error_code],
              body
            )
        end
        return response
      end
    end

  end
end
