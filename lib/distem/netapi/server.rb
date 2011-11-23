require 'distem'
require 'sinatra/base'
require 'socket'
require 'ipaddress'
require 'json'
require 'cgi'
require 'webrick'

# @private
module WEBrick
  # @private
  module Config
    General[:MaxClients] = 2048
  end
end

module Distem
  module NetAPI

    # @note Every method of the REST API should return HTTP Status following this rule:
    #
    #   * 200: OK
    #   * 400: Parameter error
    #   * 404: Resource error
    #   * 500: Shell error (check the logs)
    #   * 501: Not implemented yet
    #
    #   In addition, the HTTP Header 'X-Application-Error-Code' contains more informations about a specific error
    # @note Default return HTTP Content-Types is /application\/json/
    # @note +property+ query parameters should be in JSON hashtables format
    #
    class Server < Sinatra::Base
      HTTP_HEADER_ERR = 'X-Application-Error-Code' # @private
      HTTP_STATUS_OK = 200 # @private
      HTTP_STATUS_NOT_FOUND = 404 # @private
      HTTP_STATUS_BAD_REQUEST = 400 # @private
      HTTP_STATUS_INTERN_SERV_ERROR = 500 # @private
      HTTP_STATUS_NOT_IMPLEMENTED = 501 # @private

      set :environment, :development
      set :show_exceptions, false
      set :run, true
      set :verbose, true

      # @private
      def initialize()
        super
        @mode = settings.mode
        @daemon = Daemon::DistemDaemon.new(@mode)
      end

      # @private
      # @abstract
      def run
        raise "Server can not be run directly, use ServerDaemon or ServerNode"
      end

      # Ensure that return content_type is JSON and charset utf-8
      # @private
      before do
        @status = HTTP_STATUS_OK
        @headers = {}
        @body = {}
        @result = []
        content_type 'application/json', :charset => 'utf-8'
      end

      # Return server resource error
      # @private
      not_found do
        #response.headers[HTTP_HEADER_ERR] = \
          "ServerResourceError #{request.request_method} #{request.url}"
      end

      # Try to catch and wrapp every kind of exception
      # @private
      def check
        # >>> FIXME: remove retries hack
        retries = 4
        begin
          yield
        rescue JSON::ParserError, Lib::ParameterError => pe
          @status = HTTP_STATUS_BAD_REQUEST
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(pe)
        rescue Lib::ResourceError => re
          if retries >= 0
            sleep(0.5)
            retries -= 1
            retry
          els formate
            @status = HTTP_STATUS_NOT_FOUND
            @headers[HTTP_HEADER_ERR] = get_http_err_desc(re)
          end
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
        end
      end

      # Initialize a physical machine (launching daemon, creating cgroups, ...)
      # This step have to be performed to be able to create virtual nodes on a machine
      #
      # ==== Query parameters:
      # * *target* -- The name/address of the physical machine
      # * *properties* -- JSON Hash of:
      #   * +async+ -- asynchronious mode, check status to see when initialized (see GET /pnodes/:pnode)
      #   * +max_vifaces+ -- the maximum number of virtual network interfaces that shoud be created on this physical node
      #   * +cpu_algorithm+ -- the algorithm to be used for CPU emulation (limitations). Algorithms: _Hogs_, _Gov_.
      #
      post '/pnodes/?' do
        check do  
          props = {}
          props = JSON.parse(params['properties']) if params['properties']
          @body = @daemon.pnode_init(params['target'],props)
        end

        return result!
      end
      
      # Quit distem on a physical machine (remove everything that was created)
      delete '/pnodes/:pnode/?' do
        check do 
          @body = @daemon.pnode_quit(params['pnode'])
        end

        return result!
      end

      # Get the description of a virtual node
      get '/pnodes/:pnode/?' do
        check do
          @body = @daemon.pnode_get(params['pnode'])
        end

        return result!
      end

      # Quit distem on all the physical machines (remove everything that was created)
      delete '/pnodes/?' do
        check do 
          @body = @daemon.pnodes_quit()
        end

        return result!
      end
      
      # Get the list of the the currently created physical nodes
      get '/pnodes/?' do
        check do
          @body = @daemon.pnodes_get()
        end

        return result!
      end

      # Remove the virtual node ("Cascade" removing -> remove all the vroutes it apears as gateway)
      delete '/vnodes/:vnode/?' do
        check do
          @body = @daemon.vnode_remove(URI.unescape(params['vnode']))
        end

        return result!
      end

      # Create a virtual node using a compressed file system image.
      #
      # ==== Query parameters:
      # * *name* -- The -unique- name of the virtual node to create (it will be used in a lot of methods)
      # * *properties* -- JSON Hash of:
      #   * +target+ -- The address of the physical node the virtual node should be created on
      #   * +image+ -- The URI to a compressed archive that should contain the virtual node file system
      #   * +fs_shared+ -- Share the file system of this virtual node with every other virtual node that have this property (local to the physical node)
      #   * +async+ -- Asynchronious mode, check virtual node status to know when node is configured (see GET /vnodes/:vnode)
      #
      post '/vnodes/?' do
        check do
          props = {}
          props = JSON.parse(params['properties']) if params['properties']
          @body = @daemon.vnode_create(params['name'],props)
        end

        return result!
      end

      # Get the description of a virtual node
      get '/vnodes/:vnode/?' do
        check do
          @body = @daemon.vnode_get(URI.unescape(params['vnode']))
        end

        return result!
      end

      # Remove every virtual nodes
      delete '/vnodes/?' do
        check do
          @body = @daemon.vnodes_remove()
        end

        return result!
      end

      # Get the list of the the currently created virtual nodes
      get '/vnodes/?' do
        check do
          @body = @daemon.vnodes_get()
        end

        return result!
      end
      
      # Change the status of the -previously created- virtual node.
      #
      # ==== Query parameters:
      # * *status* -- the status to set: "Running" or "Ready"
      # * *properties* -- JSON Hash of:
      #   * +async+ -- asynchronious mode, check virtual node status (see GET /vnode/:vnode)
      #
      put '/vnodes/:vnode/?' do
        check do
          props = {}
          props = JSON.parse(params['properties']) if params['properties']
          @body = @daemon.vnode_set_status(URI.unescape(params['vnode']),
            params['status'],props)
        end

        return result!
      end
      
      # Change the mode of a virtual node (normal or gateway)
      #
      # ==== Query parameters:
      # * *mode* -- "Normal" or "Gateway"
      #
      put '/vnodes/:vnode/mode/?' do
        check do
          @body = @daemon.vnode_set_mode(URI.unescape(params['vnode']),
            params['mode'])
        end

        return result!
      end
      
      # Retrieve informations about the virtual node filesystem
      get '/vnodes/:vnode/filesystem/?' do
        check do
          @body = @daemon.vnode_filesystem_get(URI.unescape(params['vnode']))
        end

        return result!
      end

      # Get a compressed archive of the current filesystem (tgz)
      #
      # WARNING: You have to contact the physical node the vnode is hosted on directly
      get '/vnodes/:vnode/filesystem/image/?' do
        check do
          @body = @daemon.vnode_filesystem_image_get(URI.unescape(params['vnode']))
          send_file(@body, :filename => "#{params['vnode']}-fsimage.tar.gz")
        end
      end
      
      # Execute and get the result of a command on a virtual node
      #
      # ==== Query parameters:
      # * *command* -- the command to be executed
      #
      post '/vnodes/:vnode/commands/?' do
        check do
          r = @daemon.vnode_execute(URI.unescape(params['vnode']),
                                    params['command'])
          @body = (r ? r.split("\n") : [])
        end

        return result!
      end

      # Create a new virtual interface on the targeted virtual node (without attaching it to any network -> no ip address)
      #
      # ==== Query parameters:
      # * *name* -- the name of the virtual interface (need to be unique on this virtual node)
      #
      post '/vnodes/:vnode/vifaces/?' do
        check do
          @body = @daemon.viface_create(URI.unescape(params['vnode']),params['name'])
        end

        return result!
      end

      # Remove the virtual interface
      delete '/vnodes/:vnode/vifaces/:viface/?' do
        check do
          @body = @daemon.viface_remove(URI.unescape(params['vnode']),
            URI.unescape(params['viface']))
        end

        return result!
      end

      # Get the description of a virtual network interface
      get '/vnodes/:vnode/vifaces/:viface/?' do
        check do
          @body = @daemon.viface_get(URI.unescape(params['vnode']),
            URI.unescape(params['viface']))
        end

        return result!
      end

      # Create a new virtual cpu on the targeted virtual node.
      # By default all the virtual nodes on a same physical one are sharing available CPU resources, using this method you can allocate some cores to a virtual node and apply some limitations on them
      #
      # ==== Query parameters:
      # * *corenb* -- the number of cores to allocate (need to have enough free ones on the physical node)
      # * *frequency* -- (optional) the frequency each node have to be set (need to be lesser or equal than the physical core frequency). If the frequency is included in ]0,1] it'll be interpreted as a percentage of the physical core frequency, otherwise the frequency will be set to the specified number
      post '/vnodes/:vnode/vcpu/?' do
        check do
          @body = @daemon.vcpu_create(URI.unescape(params['vnode']),
            params['corenb'],params['frequency'])
        end

        return result!
      end

      # Create a new virtual network specifying his range of IP address (IPv4 atm).
      #
      # ==== Query parameters:
      # * *name* -- the -unique- name of the virtual network (it will be used in a lot of methods)
      # * *address* -- the address in the CIDR (10.0.0.1/24) or IP/NetMask (10.0.0.1/255.255.255.0) format
      #
      post '/vnetworks/?' do
        check do
          @body = @daemon.vnetwork_create(params['name'],params['address'])
        end

        return result!
      end

      # Delete the virtual network
      delete '/vnetworks/:vnetwork/?' do
        check do
          @body = @daemon.vnetwork_remove(URI.unescape(params['vnetwork']))
        end

        return result!
      end

      # Get the description of a virtual network
      get '/vnetworks/:vnetwork/?' do
        check do
          @body = @daemon.vnetwork_get(URI.unescape(params['vnetwork']))
        end

        return result!
      end

      # Delete every virtual networks
      delete '/vnetworks/?' do
        check do
          @body = @daemon.vnetworks_remove()
        end

        return result!
      end

      # Get the list of the the currently created virtual networks
      get '/vnetworks/?' do
        check do
          @body = @daemon.vnetworks_get()
        end

        return result!
      end

      # Connect a virtual node on a virtual network specifying which of it's virtual interface to use
      # The IP address is auto assigned to the virtual interface
      # Dettach the virtual interface if properties is empty
      # You can change the traffic specification on the fly, only specifying the vtraffic property
      #
      # ==== Query parameters:
      # * *properties* -- JSON Hash of :
      #   * +address+ | +vnetwork+ -- the address or the vnetwork to connect the virtual interface with
      #   * +vtraffic+ -- the traffic the interface will have to emulate (not mandatory)
      #
      #     _Format_: JSON Hash.
      #
      #     _Structure_:
      #       {
      #         Target : {
      #           Property1 : {
      #             Param1 : Value 1,
      #             Param2 : Value 2
      #           },
      #           ...
      #         }
      #       }
      #
      #     _Targets_:
      #       INPUT, OUTPUT, FULLDUPLEX
      #
      #     _Properties_:
      #       bandwidth, latency
      #
      #     Bandwidth property params:
      #       rate
      #
      #     Latency property params:
      #       delay
      #
      #   +Sample+:
      #     {
      #       "address" : "10.0.0.1",
      #       "vtraffic" :
      #       {
      #         "OUTPUT" : {
      #           "bandwidth" : {"rate" : "20mbps"},
      #           "latency" : {"delay" : "5ms"}
      #         }
      #       }
      #     }
      #
      put '/vnodes/:vnode/vifaces/:viface/?' do 
        check do
          vnodename = URI.unescape(params['vnode'])
          vifacename = URI.unescape(params['viface'])
          props = JSON.parse(params['properties']) if params['properties']
          if props and !props.empty?
            if (!props['address'] or props['address'].empty?) \
             and (!props['vnetwork'] or  props['vnetwork'].empty?) \
             and (props['vtraffic'] and !props['vtraffic'].empty?)
              @body = @daemon.viface_configure_vtraffic(vnodename,
                vifacename,props['vtraffic'])
            else
              @body = @daemon.viface_attach(vnodename,vifacename,props)
            end
          else
            @body = @daemon.viface_detach(vnodename,vifacename)
          end
        end

        return result!
      end

      # Create a virtual route ("go from <networkname> to <destnetwork> via <gatewaynode>").
      # The virtual route is applied to all the vnodes of <networkname>.
      # This method automagically set <gatewaynode> in gateway mode (if it's not already the case) and find the right virtual interface to set the virtual route on
      #
      # ==== Query parameters:
      # * *destnetwork* -- the name of the destination network
      # * *gatewaynode* -- the name of the virtual node to use as a gateway
      # Deprecated: *vnode* -- the virtual node to set the virtual route on (optional)
      #
      post '/vnetworks/:vnetwork/vroutes/?' do
        check do
          @body = @daemon.vroute_create(
            URI.unescape(params['vnetwork']),
            params['destnetwork'],
            params['gatewaynode'], params['vnode'] 
          )
        end

        return result!
      end

      # Try to create every possible virtual routes between the current
      # set of virtual nodes automagically finding and setting up
      # the gateways to use
      #
      post '/vnetworks/vroutes/complete/?' do
        check do
          @body = @daemon.vroute_complete()
        end

        return result!
      end

      # Get the description file of the current platform in a specified format (JSON if not specified)
      get '/vplatform/?:format?/?' do end

      # (see GET /vplatform/:format)
      get '/:format?/?' do end

      ['/vplatform/?:format?/?', '/:format?/?'].each do |path|
      get path do
        check do
          @body = @daemon.vplatform_get(params['format'])
          # >>> TODO: put the right format
          #send_file(ret, :filename => "vplatform")
        end

        return result!
      end
      end

      # Load a configuration
      #
      # ==== Query parameters:
      # * *data* -- data to be applied
      # * *format* -- the format of the data
      # ==== Return Content-Type:
      # +application/file+ -- The file in the requested format
      #
      post '/vplatform/?' do end

      # (see POST /vplatform)
      post '/' do end

      ['/vplatform/?', '/'].each do |path|
      post path do
        check do
          @body = @daemon.vplatform_create(params['format'],params['data'])
        end

        return result!
      end
      end

      protected

      # Setting up result (auto generate JSON if @body is a {Distem::Resource})
      # @return [Array] An array of the format [@status,@headers,@body]
      # @private
      def result!
        classname = @body.class.name.split('::').last
          #or Distem::Limitation::Network.constants.include?(classname) \
        if Distem::Resource.constants.include?(classname) \
          or @body.is_a?(Array) or @body.is_a?(Hash)
          @body = TopologyStore::HashWriter.new.visit(@body)
        end

        if @body.is_a?(Array) or @body.is_a?(Hash)
          tmpbody = @body
          begin
            @body = JSON.pretty_generate(@body)
          rescue JSON::GeneratorError
            @body = tmpbody.to_s
          end
        elsif @body.is_a?(String)
        else
          raise Lib::InvalidParameterError, "INTERNAL #{@body.class.name}"
        end

        @result = [@status,@headers,@body]

        return @result
      end

      def get_http_err_desc(except) #:nodoc:
        "#{except.class.name.split('::').last} #{except.message.to_s} | #{(settings.verbose ? except.backtrace.inspect : " ")}"
      end
    end


    # @private
    class ServerDaemon < Server
      set :mode, Daemon::DistemDaemon::MODE_DAEMON

      def initialize
        super()
        Lib::NetTools.set_bridge()
      end

      def run
        ServerDaemon.run!
      end
    end

    # @private
    class ServerNode < Server
      set :mode, Daemon::DistemDaemon::MODE_NODE

      def run
        ServerNode.run!
      end
    end

  end
end
