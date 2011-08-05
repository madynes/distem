require 'wrekavoc'
require 'rest_client'
require 'json'
require 'cgi'
require 'uri'
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

      # Initialize a physical node (create cgroups structure, set up the network interfaces, ...)
      # This step is required to be able to set up some virtual node on a physical one
      # ==== Attributes
      # * +target+ The hostname/address of the physical node
      # * +properties+ A Hash (or a JSON string) with the parameters used to set up the physical machine
      # * * +async+ Do not block waiting for the machine to install
      # ==== Returns
      # The physical node which have been initialized (Hash)
      def pnode_init(target = nil, properties = {})
        begin
          properties = properties.to_json if properties.is_a?(Hash)

          ret = {}
          req = "/pnodes"
          @resource[req].post(
            { :target => target, :properties => properties }
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

      # Same as pnode_init but in asynchronious mode
      def pnode_init!(name, properties = {})
        properties['async'] = true
        return pnode_init(name,properties)
      end

      # Quit Wrekavoc on a physical machine
      #
      # ==== Attributes
      # * +target+ The hostname/address of the physical node
      # ==== Returns
      # The physical node which have been initialized (Hash)
      def pnode_quit(target)
        begin
          ret = {}
          req = "/pnodes/#{target}"
          @resource[req].delete(
            {}
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

      # Quit Wrekavoc on every physical machines
      #
      # ==== Attributes
      # ==== Returns
      def pnodes_quit()
        begin
          ret = {}
          req = "/pnodes"
          @resource[req].delete(
            {}
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
      def pnodes_info()
        begin
          ret = {}
          req = "/pnodes"
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

      # Create a virtual node using a specific filesystem compressed image (if no physical node is specified, a random one is selected)
      # ==== Attributes
      # * +name+ The name of the virtual node which should be unique
      # * +properties+ A Hash (or a JSON string) with the parameters used to set up the virtual node
      # * * +image+ The URI to the (compressed) image file used to set up the file system
      # * * +target+ (optional) The hostname/address of the physical node to set up the virtual one on
      # * * +async+ Do not block waiting for the node to install
      # ==== Returns
      # The virtual node which have been created (Hash)
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

      # Same as vnode_create but in asynchronious mode
      def vnode_create!(name, properties)
        properties['async'] = true
        return vnode_create(name,properties)
      end

      # Remove a vnode
      # ==== Attributes
      # * +name+ The name of the virtual node
      # ==== Returns
      # The virtual node which have been removed (Hash)
      def vnode_remove(name)
        begin
          ret = {}
          req = "/vnodes/#{URI.escape(name)}"
          @resource[req].delete(
            {}
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
          req = "/vnodes/#{URI.escape(vnodename)}"
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

      # Start a virtual node 
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # ==== Returns
      # The virtual node (Hash)
      def vnode_start(vnode, properties = {})
        begin
          properties = properties.to_json if properties.is_a?(Hash)
          ret = {}
          req = "/vnodes/#{URI.escape(vnode)}"
          @resource[req].put(
            { :status => Resource::Status::RUNNING, :properties => properties }
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

      # Same as vnode_start but in asynchronious mode
      def vnode_start!(name, properties = {})
        properties['async'] = true
        return vnode_start(name,properties)
      end

      # Stop a virtual node 
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # ==== Returns
      # The virtual node (Hash)
      def vnode_stop(vnode, properties = {})
        begin
          properties = properties.to_json if properties.is_a?(Hash)
          ret = {}
          req = "/vnodes/#{URI.escape(vnode)}"
          @resource[req].put(
            { :status => Resource::Status::READY, :properties => properties }
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

      # Same as vnode_stop but in asynchronious mode
      def vnode_stop!(name, properties = {})
        properties['async'] = true
        return vnode_stop(name,properties)
      end

      # Create a virtual interface on the virtual node
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # * +vifacename+ The name of the virtual interface to be created (have to be unique on that virtual node)
      # ==== Returns
      # The virtual interface which have been created (Hash)
      def viface_create(vnode, name)
        begin
          ret = {}
          req = "/vnodes/#{URI.escape(vnode)}/vifaces"
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

      # Set up a virtual CPU on the virtual node
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # * +corenb+ The number of cores to allocate (need to have enough free ones on the physical node)
      # +frequency+ (optional) the frequency each node have to be set (need to be lesser or equal than the physical core frequency). If the frequency is included in ]0,1] it'll be interpreted as a percentage of the physical core frequency, otherwise the frequency will be set to the specified number 
      # ==== Returns
      # The virtual interface which have been created (Hash)
      def vcpu_create(vnode, corenb=1, frequency=nil)
        begin
          ret = {}
          req = "/vnodes/#{URI.escape(vnode)}/vcpu"
          @resource[req].post(
            { :corenb => corenb, :frequency => frequency }
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

      # Remove a virtual interface
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # * +vifacename+ The name of the virtual interface
      # ==== Returns
      # The virtual node which have been removed (Hash)
      def viface_remove(vnodename,vifacename)
        begin
          ret = {}
          req = "/vnodes/#{URI.escape(vnodename)}/vifaces/#{URI.escape(vifacename)}"
          @resource[req].delete(
            {}
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

      def viface_info(vnodename, vifacename)
        begin
          ret = {}
          req = "/vnodes/#{URI.escape(vnodename)}/vifaces/#{URI.escape(vifacename)}"
          @resource[req].get(
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

      # Set a virtual node in gateway mode (add the ability to forward traffic)
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # ==== Returns
      # The virtual node (Hash)
      def vnode_gateway(vnode)
        begin
          ret = {}
          req = "/vnodes/#{URI.escape(vnode)}/mode"
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

      # Retrieve informations about a virtual node filesystem
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # ==== Returns
      # The virtual node filesystem informations (Hash)
      def vnode_filesystem_info(vnode)
        begin
          ret = {}
          req = "/vnodes/#{URI.escape(vnode)}/filesystem"
          @resource[req].get(
            {}
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

      # Retrieve compressed image of the filesystem of a node
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # * +targetpath+ The path to save the file
      # ==== Returns
      # The path where the compressed image was retrieved
      def vnode_filesystem_get(vnode,target='.')
        begin
          raise Lib::ResourceNotFoundError, File.dirname(target) \
            unless File.exists?(File.dirname(target))
          if File.directory?(target)
            target = File.join(target,"#{vnode}-fsimage.tar.gz")
          end

          ret = {}
          req = "/vnodes/#{URI.escape(vnode)}/filesystem/image"
          @resource[req].get(
            {}
          ) { |response, request, result|
            ret = check_error(result,response)
            f = File.new(target,'w')
            f.syswrite(ret)
            f.close()
          }
          return ret
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{req}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        end
      end

      # Remove every vnodes
      # ==== Attributes
      # ==== Returns
      # Virtual nodes that have been removed (Array of Hash)
      def vnodes_remove()
        begin
          ret = {}
          req = "/vnodes"
          @resource[req].delete(
            {}
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
      def vnodes_info()
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

      # Create a new vitual network
      # ==== Attributes
      # * +name+ The name of the virtual network (unique)
      # * +address+ The address (CIDR format: 10.0.8.0/24) the virtual network will work with 
      # ==== Returns
      # The virtual network which have been created (Hash)
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

      # Remove a virtual network
      # ==== Attributes
      # * +name+ The name of the virtual network
      # ==== Returns
      # The virtual network which have been removed (Hash)
      def vnetwork_remove(name)
        begin
          ret = {}
          req = "/vnetworks/#{URI.escape(name)}"
          @resource[req].delete(
            {}
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
          req = "/vnetworks/#{URI.escape(vnetworkname)}"
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

      # Remove every virtual networks
      # ==== Attributes
      # ==== Returns
      # Virtual networks that have been removed (Hash)
      def vnetworks_remove()
        begin
          ret = {}
          req = "/vnetworks"
          @resource[req].delete(
            {}
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
      def vnetworks_info()
        begin
          ret = {}
          req = "/vnetworks"
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

      # Connect a virtual interface on a network and (optionally) specify the traffic the interface will have to emulate
      # ==== Attributes
      # * +vnode+ The name of the virtual node
      # * +viface+ The name of the virtual interface
      # * +properties+ An Hash (or a JSON string) containing the parameters to set up the connection
      # * * +vnetwork+ The name of the virtual network to connect the interface on
      # * * +address+ The address of the virtual interface
      # One of this two parameters have to be set (if it's vnetwork, the address is automatically set)
      # * * +vtraffic+ ...
      # ==== Returns
      # The virtual interface (Hash)
      def viface_attach(vnode, viface, properties)
        begin
          properties = properties.to_json if properties.is_a?(Hash)
          ret = {}
          req = "/vnodes/#{URI.escape(vnode)}/vifaces/#{URI.escape(viface)}"
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

      # Disconnect a virtual interface from the network it's connected to
      # ==== Attributes
      # * +vnode+ The name of the virtual node
      # * +viface+ The name of the virtual interface
      # ==== Returns
      # The virtual interface (Hash)
      def viface_detach(vnode, viface)
        begin
          ret = {}
          req = "/vnodes/#{URI.escape(vnode)}/vifaces/#{URI.escape(viface)}"
          @resource[req].put(
            {}
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

      # Create a new virtual route between two virtual networks ("NetDestination is accessible from NetSource using NodeGateway")
      # ==== Attributes
      # * +srcnet+ The name of the source virtual network
      # * +destnet+ The name of the destination virtual network
      # * +gateway+ The name of the virtual node to use as gateway (this node have to be connected on both of the previously mentioned networks), the node is automatically set in gateway mode
      # ==== Returns
      # The virtual route which have been created (Hash)

      def vroute_create(srcnet,destnet,gateway,vnode="")
        begin
          ret = {}
          req = "/vnetworks/#{URI.escape(srcnet)}/vroutes"
          @resource[req].post(
            { :destnetwork => destnet,
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

      # Create all possible virtual routes between all the virtual networks, automagically choosing the virtual nodes to use as gateway
      # ==== Returns
      # All the virtual routes which have been created (Array of Hashes)

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

      # Execute the specified command on the virtual node
      # ==== Attributes
      # * +vnode+ The name of the virtual node
      # * +command+ The command to be executed
      # ==== Returns
      # A Hash with the command which have been performed and the resold of it

      def vnode_execute(vnode, command)
        begin
          ret = {}
          req = "/vnodes/#{URI.escape(vnode)}/commands"
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

      # Create an set a platform with backup data
      # ==== Attributes
      # * +format+ The input data format (default is JSON)
      # * +data+ The data used to create the vplatform
      # ==== Returns
      # The description of the vplatform

      def vplatform_create(data,format = 'JSON')
        begin
          ret = {}
          req = "/vplatform"
          @resource[req].post(
            { 'format' => format, 'data' => data }
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

      # Get the full description of the platform
      # ==== Attributes
      # * +format+ The wished output format (default is JSON)
      # ==== Returns
      # The description in the wished format

      def vplatform_info(format = 'JSON')
        begin
          ret = {}
          req = "/vplatform/#{format}"
          @resource[req].get(
            {}
          ) { |response, request, result|
            ret = check_error(result,response)
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
