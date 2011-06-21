require 'wrekavoc'
require 'sinatra/base'
require 'socket'
require 'ipaddress'
require 'json'

module Wrekavoc
  module NetAPI

    class Server < Sinatra::Base
      HTTP_HEADER_ERR = 'X-Application-Error-Code'
      HTTP_STATUS_OK = 200
      HTTP_STATUS_NOT_FOUND = 404
      HTTP_STATUS_BAD_REQUEST = 400
      HTTP_STATUS_INTERN_SERV_ERROR = 500
      HTTP_STATUS_NOT_IMPLEMENTED = 501

      set :environment, :developpement
      set :run, true

      def initialize() #:nodoc:
        super
        @mode = settings.mode
        @daemon = Daemon::WrekaDaemon.new(@mode)
      end

      def run #:nodoc:
        raise "Server can not be run directly, use ServerDaemon or ServerNode"
      end

      before do
        @status = HTTP_STATUS_OK
        @headers = {}
        @body = {}
        content_type 'application/json', :charset => 'utf-8'
      end

      ##
      # :method: post(/pnodes)
      #
      # :call-seq:
      #   POST /pnodes
      # 
      # Initialise a physical machine (launching daemon, creating cgroups, ...)
      # This step have to be performed to be able to create virtual nodes on a machine 
      #
      # == Query parameters
      # <tt>target</tt>:: the name/address of the physical machine
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      #
      post '/pnodes' do
        begin 
          ret = @daemon.pnode_init(params['target'])
        rescue Lib::ParameterError => pe
          @status = HTTP_STATUS_BAD_REQUEST
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(pe)
        rescue Lib::ResourceError => re
          @status = HTTP_STATUS_NOT_FOUND
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(re)
        rescue Lib::ClientError => ce
          @status = ce.num
          @headers[HTTP_HEADER_ERR] = ce.desc
          @body = ce.body
        else
          @body = JSON.pretty_generate(ret.to_hash)
        end

        return [@status,@headers,@body]
      end

      ##
      # :method: get(/pnodes/:pnodename)
      #
      # :call-seq:
      #   GET /pnodes/:pnodename
      # 
      # Get the description of a virtual node
      #
      # == Query parameters
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      #
      get '/pnodes/:pnode' do
        begin
          ret = @daemon.pnode_get(params['pnode'])
        rescue JSON::ParserError, Lib::ParameterError => pe
          @status = HTTP_STATUS_BAD_REQUEST
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(pe)
        rescue Lib::ResourceError => re
          @status = HTTP_STATUS_NOT_FOUND
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(re)
        rescue Lib::NotImplementedError => ni
          @status = HTTP_STATUS_NOT_IMPLEMENTED
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(ni)
        rescue Lib::ShellError => se
          @status = HTTP_STATUS_INTERN_SERV_ERROR
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(se)
        rescue Lib::ClientError => ce
          @status = ce.num
          @headers[HTTP_HEADER_ERR] = ce.desc
          @body = ce.body
        else
          @body = JSON.pretty_generate(ret.to_hash)
        end

        return [@status,@headers,@body]
      end

      ##
      # :method: post(/vnodes)
      #
      # :call-seq:
      #   POST /vnodes
      # 
      # Create a virtual node using a compressed file system image.
      #
      # == Query parameters
      # <tt>name</tt>:: the -unique- name of the virtual node to create (it will be used in a lot of methods)
      # <tt>properties</tt>:: target,image
      # 
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      #
      post '/vnodes' do
        begin
          ret = @daemon.vnode_create(params['name'], \
            JSON.parse(params['properties']) \
          )
        rescue JSON::ParserError, Lib::ParameterError => pe
          @status = HTTP_STATUS_BAD_REQUEST
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(pe)
        rescue Lib::ResourceError => re
          @status = HTTP_STATUS_NOT_FOUND
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(re)
        rescue Lib::NotImplementedError => ni
          @status = HTTP_STATUS_NOT_IMPLEMENTED
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(ni)
        rescue Lib::ShellError => se
          @status = HTTP_STATUS_INTERN_SERV_ERROR
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(se)
        rescue Lib::ClientError => ce
          @status = ce.num
          @headers[HTTP_HEADER_ERR] = ce.desc
          @body = ce.body
        else
          @body = JSON.pretty_generate(ret.to_hash)
        end

        return [@status,@headers,@body]
      end
      
      ##
      # :method: get(/vnodes/:vnodename)
      #
      # :call-seq:
      #   GET /vnodes/:vnodename
      # 
      # Get the description of a virtual node
      #
      # == Query parameters
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      #
      get '/vnodes/:vnode' do
        begin
          ret = @daemon.vnode_get(params['vnode'])
        rescue JSON::ParserError, Lib::ParameterError => pe
          @status = HTTP_STATUS_BAD_REQUEST
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(pe)
        rescue Lib::ResourceError => re
          @status = HTTP_STATUS_NOT_FOUND
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(re)
        rescue Lib::NotImplementedError => ni
          @status = HTTP_STATUS_NOT_IMPLEMENTED
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(ni)
        rescue Lib::ShellError => se
          @status = HTTP_STATUS_INTERN_SERV_ERROR
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(se)
        rescue Lib::ClientError => ce
          @status = ce.num
          @headers[HTTP_HEADER_ERR] = ce.desc
          @body = ce.body
        else
          @body = JSON.pretty_generate(ret.to_hash)
        end

        return [@status,@headers,@body]
      end

      ##
      # :method: get(/vnodes)
      #
      # :call-seq:
      #   GET /vnodes
      # 
      # Get the list of the the currently created virtual nodes
      #
      # == Query parameters
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      get '/vnodes' do
        ret = @daemon.vnode_list_get()
        @body = JSON.pretty_generate(ret)
        return [@status,@headers,@body]
      end
      
      ##
      # :method: put(/vnodes/:vnodename)
      #
      # :call-seq:
      #   PUT /vnodes/:vnodename
      # 
      # Change the status of the -previously created- virtual node.
      #
      # == Query parameters
      # <tt>status</tt>:: the status to set: "Running" or "Stopped"
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      #
      put '/vnodes/:vnode' do
        begin
          ret = @daemon.vnode_set_status(params['vnode'],params['status'])
        rescue JSON::ParserError, Lib::ParameterError => pe
          @status = HTTP_STATUS_BAD_REQUEST
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(pe)
        rescue Lib::ResourceError => re
          @status = HTTP_STATUS_NOT_FOUND
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(re)
        rescue Lib::NotImplementedError => ni
          @status = HTTP_STATUS_NOT_IMPLEMENTED
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(ni)
        rescue Lib::ShellError => se
          @status = HTTP_STATUS_INTERN_SERV_ERROR
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(se)
        rescue Lib::ClientError => ce
          @status = ce.num
          @headers[HTTP_HEADER_ERR] = ce.desc
          @body = ce.body
        else
          @body = JSON.pretty_generate(ret.to_hash)
        end

        return [@status,@headers,@body]
      end

      ##
      # :method: post(/vnodes/:vnodename/vifaces)
      #
      # :call-seq:
      #   POST /vnodes/:vnodename/vifaces
      # 
      # Create a new virtual interface on the targeted virtual node (without attaching it to any network -> no ip address)
      #
      # == Query parameters
      # <tt>name</tt>:: the name of the virtual interface (need to be unique on this virtual node)
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      #
      post '/vnodes/*/vifaces' do
        begin
          ret = @daemon.viface_create(params[:splat][0],params['name'])
        rescue JSON::ParserError, Lib::ParameterError => pe
          @status = HTTP_STATUS_BAD_REQUEST
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(pe)
        rescue Lib::ResourceError => re
          @status = HTTP_STATUS_NOT_FOUND
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(re)
        rescue Lib::NotImplementedError => ni
          @status = HTTP_STATUS_NOT_IMPLEMENTED
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(ni)
        rescue Lib::ShellError => se
          @status = HTTP_STATUS_INTERN_SERV_ERROR
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(se)
        rescue Lib::ClientError => ce
          @status = ce.num
          @headers[HTTP_HEADER_ERR] = ce.desc
          @body = ce.body
        else
          @body = JSON.pretty_generate(ret.to_hash)
        end

        return [@status,@headers,@body]
      end

      post VNODE_GATEWAY do
        ret = @daemon.vnode_gateway(params['vnode'])
        return JSON.pretty_generate(ret)
      end
      
      post VNODE_INFO_ROOTFS do
        ret = @daemon.vnode_info_rootfs(params['vnode'])
        return JSON.pretty_generate(ret)
      end
      
      ##
      # :method: post(/vnodes/:vnodename/commands)
      #
      # :call-seq:
      #   POST /vnodes/:vnodename/commands
      # 
      # Execute and get the result of a command on a virtual node
      #
      # == Query parameters
      # <tt>command</tt>:: the command to be executed
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      #
      post '/vnodes/*/commands' do
        ret = @daemon.vnode_execute(params[:splat][0],params['command'])
        return JSON.pretty_generate(ret)
      end
      
      ##
      # :method: post(/vnetworks)
      #
      # :call-seq:
      #   POST /vnetworks
      # 
      # Create a new virtual network specifying his range of IP address (IPv4 atm).
      #
      # == Query parameters
      # <tt>name</tt>:: the -unique- name of the virtual network (it will be used in a lot of methods)
      # <tt>address</tt>:: the address in the CIDR (10.0.0.1/24) or IP/NetMask (10.0.0.1/255.255.255.0) format
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      #
      post '/vnetworks' do
        begin
          ret = @daemon.vnetwork_create(params['name'],params['address'])
        rescue Lib::ParameterError => pe
          @status = HTTP_STATUS_BAD_REQUEST
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(pe)
        rescue Lib::ResourceError => re
          @status = HTTP_STATUS_NOT_FOUND
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(re)
        rescue Lib::ShellError => se
          @status = HTTP_STATUS_INTERN_SERV_ERROR
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(se)
        rescue Lib::ClientError => ce
          @status = ce.num
          @headers[HTTP_HEADER_ERR] = ce.desc
          @body = ce.body
        else
          @body = JSON.pretty_generate(ret.to_hash)
        end

        return [@status,@headers,@body]
      end

      ##
      # :method: get(/vnetworks/:vnetworkname)
      #
      # :call-seq:
      #   GET /vnetworks/:vnetworkname
      # 
      # Get the description of a virtual network
      #
      # == Query parameters
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      #
      get '/vnetworks/:vnetwork' do
        begin
          ret = @daemon.vnetwork_get(params['vnetwork'])
        rescue JSON::ParserError, Lib::ParameterError => pe
          @status = HTTP_STATUS_BAD_REQUEST
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(pe)
        rescue Lib::ResourceError => re
          @status = HTTP_STATUS_NOT_FOUND
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(re)
        rescue Lib::NotImplementedError => ni
          @status = HTTP_STATUS_NOT_IMPLEMENTED
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(ni)
        rescue Lib::ShellError => se
          @status = HTTP_STATUS_INTERN_SERV_ERROR
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(se)
        rescue Lib::ClientError => ce
          @status = ce.num
          @headers[HTTP_HEADER_ERR] = ce.desc
          @body = ce.body
        else
          @body = JSON.pretty_generate(ret.to_hash)
        end

        return [@status,@headers,@body]
      end

      ##
      # :method: put(/vnodes/:vnodename/vifaces/:vifacename)
      #
      # :call-seq:
      #   PUT /vnodes/:vnodename/vifaces/:vifacename
      # 
      # Connect a virtual node on a virtual network specifying which of it's virtual interface to use
      # The IP address is auto assigned to the virtual interface
      #
      # == Query parameters
      # <tt>properties</tt>:: the address or the vnetwork to connect the virtual interface with (JSON, 'address' or 'vnetwork)
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      put '/vnodes/*/vifaces/*' do
        begin
          ret = @daemon.viface_attach(params[:splat][0],params[:splat][1],
            JSON.parse(params['properties'])
          )
        rescue JSON::ParserError, Lib::ParameterError => pe
          @status = HTTP_STATUS_BAD_REQUEST
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(pe)
        rescue Lib::ResourceError => re
          @status = HTTP_STATUS_NOT_FOUND
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(re)
        rescue Lib::ShellError => se
          @status = HTTP_STATUS_INTERN_SERV_ERROR
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(se)
        rescue Lib::ClientError => ce
          @status = ce.num
          @headers[HTTP_HEADER_ERR] = ce.desc
          @body = ce.body
        else
          @body = JSON.pretty_generate(ret.to_hash)
        end

        return [@status,@headers,@body]
      end


      ##
      # :method: post(/vnetworks/:networksrc/vroutes)
      #
      # :call-seq:
      #   POST /vnetworks/:networksrc/vroutes
      # 
      # Create a virtual route ("go from Net1 to Net2 via NodeGW") on a virtual node
      # (this method automagically set NodeGW as a gateway if it's not already the case
      # and find the right virtual interface to set the virtual route on)
      #
      # == Query parameters
      # <tt>networkdst</tt>:: the name of the destination network
      # <tt>gatewaynode</tt>:: the name of the virtual node to use as a gateway
      # <tt>vnode</tt>:: the virtual node to set the virtual route on (optional)
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      #
      post VROUTE_CREATE do
        ret = @daemon.vroute_create(params['networksrc'],params['networkdst'], \
          params['gatewaynode'], params['vnode'] \
        )
        return JSON.pretty_generate(ret)
      end
      
      ##
      # :method: post(/vnetworks/vroutes/complete)
      #
      # :call-seq:
      #   POST /vnetworks/vroutes/complete
      # 
      # Try to create every possible virtual routes between the current 
      # set of virtual nodes automagically finding and setting up 
      # the gateways to use
      #
      # == Query parameters
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # ...
      
      #
      post VROUTE_COMPLETE do
        ret = @daemon.vroute_complete()
        return JSON.pretty_generate(ret)
      end
      
      ##
      # :method: post(/limitations/network)
      #
      # :call-seq:
      #   POST /limitations/network
      # 
      # Create a new network limitation on a specific interface of a virtual node
      #
      # == Query parameters
      # <tt>vnode</tt>:: the name of the virtual node to set the limitation on
      # <tt>viface</tt>:: the name of the virtual interface targeted
      # <tt>properties</tt>:: the properties of the limitation in JSON format
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # Check the content of the header 'X-Application-Error-Code' for more informations about an error
      # <tt>200</tt>:: OK
      # <tt>400</tt>:: Parameter error 
      # <tt>404</tt>:: Resource error
      # <tt>500</tt>:: Shell error (check the logs)
      # <tt>501</tt>:: Not implemented yet
      # 
      # == Usage
      # properties sample: { "OUTPUT" : { "bandwidth" : {"rate" : "20mbps"}, "latency" : {"delay" : "5ms"} } }
      #
      
      #
      post LIMIT_NET_CREATE do
        ret = @daemon.limit_net_create(params['vnode'],params['viface'], \
          JSON.parse(params['properties']) \
        )
        return JSON.pretty_generate(ret)
      end

      protected

      def get_http_err_desc(except) #:nodoc:
        except.class.name.split('::').last + " " + except.message
      end
    end


    class ServerDaemon < Server #:nodoc:
      set :mode, Daemon::WrekaDaemon::MODE_DAEMON

      def initialize
        super()
        Lib::NetTools.set_bridge()
      end

      def run
        ServerDaemon.run!
      end
    end

    class ServerNode < Server #:nodoc:
      set :mode, Daemon::WrekaDaemon::MODE_NODE

      def run
        ServerNode.run!
      end
    end

  end
end
