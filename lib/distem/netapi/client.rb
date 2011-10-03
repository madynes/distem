require 'distem'
require 'rest_client'
require 'json'
require 'cgi'
require 'uri'
require 'pp'

module Distem
  module NetAPI

    class Client
      # The maximum number of simultaneous requests
      MAX_SIMULTANEOUS_REQ = 64
      # The HTTP OK status value
      HTTP_STATUS_OK = 200

      # The default timeout
      TIMEOUT=900

      @@semreq = Lib::Semaphore.new(MAX_SIMULTANEOUS_REQ)

      # Create a new Client and connect it to a specified REST(distem) server
      # ==== Attributes
      # * +serveraddr+ The REST server address (String)
      # * +port+ The port the REST server is listening on
      #
      def initialize(serveraddr="localhost",port=4567, semsize = nil)
        raise unless port.is_a?(Numeric)
        @serveraddr = serveraddr
        @serverurl = 'http://' + @serveraddr + ':' + port.to_s
        @resource = RestClient::Resource.new(@serverurl, :timeout => TIMEOUT, :open_timeout => (TIMEOUT/2))
        @@semreq = Lib::Semaphore.new(semsize) if semsize and @@semreq.size != semsize
        @resource
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
        check_net("/pnodes") do |req|
          properties = properties.to_json if properties.is_a?(Hash)
          ret = {}
          @resource[req].post(
            { :target => target, :properties => properties }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Same as pnode_init but in asynchronious mode
      def pnode_init!(name, properties = {})
        properties['async'] = true
        return pnode_init(name,properties)
      end

      # Quit distem on a physical machine
      #
      # ==== Attributes
      # * +target+ The hostname/address of the physical node
      # ==== Returns
      # The physical node which have been initialized (Hash)
      def pnode_quit(target)
        check_net("/pnodes/#{target}") do |req|
          ret = {}
          @resource[req].delete(
            {}
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
        end
      end

      # Retrieve informations about a physical node
      # ==== Attributes
      # * +pnodename+ The address/name of the physical node
      # ==== Returns
      # The physical node informations (Hash)
      def pnode_info(pnodename='localhost')
        check_net("/pnodes/#{pnodename}") do |req|
          ret = {}
          @resource[req].get { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Quit distem on every physical machines
      #
      def pnodes_quit()
        check_net("/pnodes") do |req|
          ret = {}
          @resource[req].delete(
            {}
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Retrieve informations about every physical nodes currently set on the platform
      # ==== Returns
      # The virtual nodes informations (Array of Hashes, see pnode_info)
      def pnodes_info()
        check_net("/pnodes") do |req|
          ret = {}
          @resource[req].get { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
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
        check_net('/vnodes') do |req|
          ret = {}
          properties = properties.to_json if properties.is_a?(Hash)
          @resource[req].post(
            { :name => name , :properties => properties }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
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
        check_net("/vnodes/#{URI.escape(name)}") do |req|
          ret = {}
          @resource[req].delete(
            {}
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Retrieve informations about a virtual node
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # ==== Returns
      # The virtual node informations (Hash)
      def vnode_info(vnodename)
        check_net("/vnodes/#{URI.escape(vnodename)}") do |req|
          ret = {}
          @resource[req].get { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Start a virtual node 
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # ==== Returns
      # The virtual node (Hash)
      def vnode_start(vnode, properties = {})
        check_net("/vnodes/#{URI.escape(vnode)}") do |req|
          ret = {}
          properties = properties.to_json if properties.is_a?(Hash)
          @resource[req].put(
            { :status => Resource::Status::RUNNING, :properties => properties }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
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
        check_net("/vnodes/#{URI.escape(vnode)}") do |req|
          ret = {}
          properties = properties.to_json if properties.is_a?(Hash)
          @resource[req].put(
            { :status => Resource::Status::READY, :properties => properties }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
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
        check_net("/vnodes/#{URI.escape(vnode)}/vifaces") do |req|
          ret = {}
          @resource[req].post(
            { :name => name }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
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
        check_net("/vnodes/#{URI.escape(vnode)}/vcpu") do |req|
          ret = {}
          @resource[req].post(
            { :corenb => corenb, :frequency => frequency }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Remove a virtual interface
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # * +vifacename+ The name of the virtual interface
      # ==== Returns
      # The virtual node which have been removed (Hash)
      def viface_remove(vnodename,vifacename)
        check_net("/vnodes/#{URI.escape(vnodename)}/vifaces/#{URI.escape(vifacename)}") do |req|
          ret = {}
          @resource[req].delete(
            {}
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Retrieve informations about a virtual network interface associated to a virtual node
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # * +vifacename+ The name of the virtual network interface
      # ==== Returns
      # The virtual network interface informations (Hash)
      def viface_info(vnodename, vifacename)
        check_net("/vnodes/#{URI.escape(vnodename)}/vifaces/#{URI.escape(vifacename)}") do |req|
          ret = {}
          @resource[req].get(
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Set a virtual node in gateway mode (add the ability to forward traffic)
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # ==== Returns
      # The virtual node (Hash)
      def vnode_gateway(vnode)
        check_net("/vnodes/#{URI.escape(vnode)}/mode") do |req|
          ret = {}
          @resource[req].put(
            { :mode => Resource::VNode::MODE_GATEWAY }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Retrieve informations about a virtual node filesystem
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # ==== Returns
      # The virtual node filesystem informations (Hash)
      def vnode_filesystem_info(vnode)
        check_net("/vnodes/#{URI.escape(vnode)}/filesystem") do |req|
          ret = {}
          @resource[req].get(
            {}
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Retrieve compressed image of the filesystem of a node
      # ==== Attributes
      # * +vnodename+ The name of the virtual node
      # * +targetpath+ The path to save the file
      # ==== Returns
      # The path where the compressed image was retrieved
      def vnode_filesystem_get(vnode,target='.')
        check_net("/vnodes/#{URI.escape(vnode)}/filesystem/image") do |req|
          raise Lib::ResourceNotFoundError, File.dirname(target) \
            unless File.exists?(File.dirname(target))
          if File.directory?(target)
            target = File.join(target,"#{vnode}-fsimage.tar.gz")
          end

          ret = {}
          @resource[req].get(
            {}
          ) { |response, request, result|
            ret = check_error(result,response)
            f = File.new(target,'w')
            f.syswrite(ret)
            f.close()
          }
          ret
        end
      end

      # Remove every vnodes
      # ==== Returns
      # Virtual nodes that have been removed (Array of Hash)
      def vnodes_remove()
        check_net("/vnodes") do |req|
          ret = {}
          @resource[req].delete(
            {}
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end


      # Retrieve informations about every virtual nodes currently set on the platform
      # ==== Returns
      # The virtual nodes informations (Array of Hashes, see vnode_info)
      def vnodes_info()
        check_net("/vnodes") do |req|
          ret = {}
          @resource[req].get({}) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Create a new vitual network
      # ==== Attributes
      # * +name+ The name of the virtual network (unique)
      # * +address+ The address (CIDR format: 10.0.8.0/24) the virtual network will work with 
      # ==== Returns
      # The virtual network which have been created (Hash)
      def vnetwork_create(name, address)
        check_net("/vnetworks") do |req|
          ret = {}
          @resource[req].post(
            { :name => name, :address => address }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Remove a virtual network
      # ==== Attributes
      # * +name+ The name of the virtual network
      # ==== Returns
      # The virtual network which have been removed (Hash)
      def vnetwork_remove(name)
        check_net("/vnetworks/#{URI.escape(name)}") do |req|
          ret = {}
          @resource[req].delete(
            {}
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Retrieve informations about a virtual network
      # ==== Attributes
      # * +vnetworkname+ The name of the virtual network
      # ==== Returns
      # The virtual network informations (Hash)
      def vnetwork_info(vnetworkname)
        check_net("/vnetworks/#{URI.escape(vnetworkname)}") do |req|
          ret = {}
          @resource[req].get { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Remove every virtual networks
      # ==== Attributes
      # ==== Returns
      # Virtual networks that have been removed (Hash)
      def vnetworks_remove()
        check_net("/vnetworks") do |req|
          ret = {}
          @resource[req].delete(
            {}
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Retrieve informations about every virtual networks currently set on the platform
      # ==== Returns
      # The virtual networks informations (Array of Hash, see vnetwork_info)
      def vnetworks_info()
        check_net("/vnetworks") do |req|
          ret = {}
          @resource[req].get { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
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
        check_net("/vnodes/#{URI.escape(vnode)}/vifaces/#{URI.escape(viface)}") do |req|
          properties = properties.to_json if properties.is_a?(Hash)
          ret = {}
          
          @resource[req].put(
            { :properties => properties }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Disconnect a virtual interface from the network it's connected to
      # ==== Attributes
      # * +vnode+ The name of the virtual node
      # * +viface+ The name of the virtual interface
      # ==== Returns
      # The virtual interface (Hash)
      def viface_detach(vnode, viface)
        check_net("/vnodes/#{URI.escape(vnode)}/vifaces/#{URI.escape(viface)}") do |req|
          ret = {}
          @resource[req].put(
            {}
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
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
        check_net("/vnetworks/#{URI.escape(srcnet)}/vroutes") do |req|
          ret = {}
          @resource[req].post(
            { :destnetwork => destnet,
              :gatewaynode => gateway, :vnode => vnode }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Create all possible virtual routes between all the virtual networks, automagically choosing the virtual nodes to use as gateway
      # ==== Returns
      # All the virtual routes which have been created (Array of Hashes)
      def vroute_complete()
        check_net("/vnetworks/vroutes/complete") do |req|
          ret = {}
          @resource[req].post({}) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Execute the specified command on the virtual node
      # ==== Attributes
      # * +vnode+ The name of the virtual node
      # * +command+ The command to be executed
      # ==== Returns
      # A Hash with the command which have been performed and the resold of it
      def vnode_execute(vnode, command)
        check_net("/vnodes/#{URI.escape(vnode)}/commands") do |req|
          ret = {}
          @resource[req].post(
            { :command => command }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Create an set a platform with backup data
      # ==== Attributes
      # * +format+ The input data format (default is JSON)
      # * +data+ The data used to create the vplatform
      # ==== Returns
      # The description of the vplatform

      def vplatform_create(data,format = 'JSON')
        check_net("/vplatform") do |req|
          ret = {}
          @resource[req].post(
            { 'format' => format, 'data' => data }
          ) { |response, request, result|
            ret = JSON.parse(check_error(result,response))
          }
          ret
        end
      end

      # Get the full description of the platform
      # ==== Attributes
      # * +format+ The wished output format (default is JSON)
      # ==== Returns
      # The description in the wished format
      def vplatform_info(format = 'JSON')
        check_net("/vplatform/#{format}") do |req|
          ret = {}
          @resource[req].get(
            {}
          ) { |response, request, result| ret = check_error(result,response) }
          ret
        end
      end

      protected

      # Check if there was an error in the REST request
      # ==== Attributes
      # * +result+ the result header (see RestClient)
      # * +response+ the response header (see RestClient)
      # ==== Returns
      # The response header object if no problems found (String)
      # ==== Exceptions
      # * +ClientError+ if the HTTP status returned performing the request is not HTTP_OK, the Exception object contains the description of the error
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

      # Check if there was an error related to the network connection
      # ==== Attributes
      # * +route+ the route path to access (REST)
      # ==== Returns
      # ==== Exceptions
      # * +InvalidParameterError+ if given path is not available on the server
      # * +UnavailableResourceError+ if for one reason or another the host is unreachable
      def check_net(route)
        @@semreq.acquire
        begin
          yield(route)
        rescue RestClient::RequestFailed
          raise Lib::InvalidParameterError, "#{@serverurl}#{route}"
        rescue RestClient::Exception, Errno::ECONNREFUSED, Timeout::Error, \
          RestClient::RequestTimeout, Errno::ECONNRESET, SocketError
          raise Lib::UnavailableResourceError, @serverurl
        ensure
          @@semreq.release
        end
      end
    end

  end
end
