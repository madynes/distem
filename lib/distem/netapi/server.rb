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
    #   * 200: OK
    #   * 400: Parameter error
    #   * 404: Resource error
    #   * 500: Shell error (check the logs)
    #   * 501: Not implemented yet
    #
    #   In addition, the HTTP Header 'X-Application-Error-Code' contains more informations about a specific error
    # @note Default return HTTP Content-Types is application/json
    # @note +desc+ query parameters should be in JSON hashtables format. Also, Every HTTP/POST parameter is optional by default (it's specified in the documentation otherwise).
    # @note For +desc+ query parameters, the only elements in the structure (JSON Hash) that will be taken in account are those listed as *writable* in {file:files/resources_desc.md Resources Description}.
    # @note Most of changes you can perform on virtual nodes resources are taking effect after stopping then starting back the resource. Changes that are applied on-the-fly are documented as this.
    # @note In this page, in routes/paths described such as /resource/:name, +:name+ should be remplaced by a value that describe the resource to target (sample: /resource/test). Also, in routes/paths, the '?' char means that the precedent char -in the path- is optional, so /resource/? means that the resource should be access either by the routes/paths /resource and /resource/ .
    # @note Returned data are JSON Hash of the corresponding object described in {file:files/resources_desc.md Resources Description}.
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
      set :raise_errors, true
      set :run, true
      set :bind, '0.0.0.0'
      set :server, 'webrick'

      # @private
      def initialize()
        super
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
#        retries = 2
        begin
          yield
        rescue JSON::ParserError, Lib::ParameterError => pe
          @status = HTTP_STATUS_BAD_REQUEST
          @headers[HTTP_HEADER_ERR] = get_http_err_desc(pe)
=begin
        rescue Lib::ResourceNotFoundError, Lib::BusyResourceError => re
          if retries >= 0
            sleep(0.5)
            retries -= 1
            retry
          else
            @status = HTTP_STATUS_NOT_FOUND
            @headers[HTTP_HEADER_ERR] = get_http_err_desc(re)
          end
=end
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
        end
      end

      # Launch a set of probes on the physical nodes. Physical nodes have to initialized
      # before doing that
      #
      # ==== Query parameters:
      # * *desc* -- JSON Hash structured as follows: { 'probe1_type' => { 'name' => probe1_name, 'frequency' => freq, ...}}}
      post '/pnodes/probes' do
        check do
          desc = JSON.parse(params['desc'])
          ref_time = params.has_key?('ref_time') ? params['ref_time'] : nil
          @daemon.pnodes_launch_probes(desc, ref_time)
          @body = ""
        end
      end

      # Stop or restart the probes
      put '/pnodes/probes' do
        check do
          if params['state'] == 'stop'
            @daemon.pnodes_stop_probes()
          else
            @daemon.pnodes_restart_probes()
          end
          @body = ""
        end
      end

      # Get the data collected from the probes
      get '/pnodes/probes' do
        check do
          @body = @daemon.pnodes_get_probes_data().to_json
        end
        return result!
      end

      # Delete the probes
      delete '/pnodes/probes' do
        check do
          @daemon.pnodes_delete_probes()
          @body = ""
        end
      end

      # Initialize a physical machine (launching daemon, creating cgroups, ...)
      # This step have to be performed to be able to create virtual nodes on a machine
      #
      # ==== Query parameters:
      # * *target* -- _mandatory_ -- The name/address of the physical machine
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#pnode Resource Description - PNode}.
      # * *async* -- Asynchronious mode, check the physical node status to know when the configuration is done (see GET /pnodes/:pnode)
      post '/pnodes/?' do
        check do
          desc = {}
          desc = JSON.parse(params['desc']) if params['desc']
          target = (params['target'] == "") ? nil : JSON.parse(params['target'])
          @body = @daemon.pnode_create(target,desc,params['async'])
        end
        return result!
      end

      # Get the description of a physical node
      get '/pnodes/:pnode/?' do
        check do
          @body = @daemon.pnode_get(params['pnode'])
        end

        return result!
      end

      # Update a physical machine configuration
      #
      # ==== Query parameters:
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#pnode Resource Description - PNode}.
      put '/pnodes/:pnode/?' do
        check do
          desc = {}
          desc = JSON.parse(params['desc']) if params['desc']
          @body = @daemon.pnode_update(params['pnode'],desc)
        end

        return result!
      end

      # Quit distem on a physical machine (remove everything that was created)
      delete '/pnodes/:pnode/?' do
        check do
          @body = @daemon.pnode_quit(params['pnode'])
        end

        Thread.new {
          sleep 2
          exit!
        }
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

      # Get the description of the CPU of a physical node
      get '/pnodes/:pnode/cpu/?' do
        check do
          @body = @daemon.pcpu_get(params['pnode'])
        end

        return result!
      end

      # Get the description of the memory of a physical node
      get '/pnodes/:pnode/memory/?' do
        check do
          @body = @daemon.pmemory_get(params['pnode'])
        end

        return result!
      end

      # Create a new virtual node
      #
      # ==== Query parameters:
      # * *name* -- _mandatory_, _unique_ -- The unique name of the virtual node to create (it will be used in a lot of methods)
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode Resource Description - VNode}.
      # * *ssh_key* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode_sshkey Resource Description - SSH Key}.
      # * *async* -- Asynchronious mode, check virtual node status to know when node is configured (see GET /vnodes/:vnode)
      post '/vnodes/:vnodename/?' do
        check do
          desc = {}
          ssh_key = {}
          desc = JSON.parse(params['desc']) if params['desc']
          ssh_key = JSON.parse(params['ssh_key']) if params['ssh_key']
          @body = @daemon.vnode_create(CGI.unescape(params['vnodename']), desc, ssh_key, params['async']).first
        end

        return result!
      end

      # Create several virtual node
      #
      # ==== Query parameters:
      # * *names* -- _mandatory_, _unique_ -- The names of the virtual nodes to create (it will be used in a lot of methods)
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode Resource Description - VNode}.
      # * *ssh_key* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode_sshkey Resource Description - SSH Key}.
      # * *async* -- Asynchronious mode, check virtual node status to know when node is configured (see GET /vnodes/:vnode)
      post '/vnodes/?' do
        check do
          desc = {}
          ssh_key = {}
          desc = JSON.parse(params['desc']) if params['desc']
          ssh_key = JSON.parse(params['ssh_key']) if params['ssh_key']
          @body = @daemon.vnode_create(JSON.parse(params['names']), desc, ssh_key, params['async'])
        end

        return result!
      end

      # Get the description of a virtual node
      get '/vnodes/:vnodename/?' do
        check do
          @body = @daemon.vnode_get_info(CGI.unescape(params['vnodename']))
        end

        return result!
      end

      # Get the list of the the currently created virtual nodes
      get '/vnodes/?' do
        check do
          @body = @daemon.vnodes_get_info()
        end

        return result!
      end

      # Update or stop the virtual node following a new description
      #
      # ==== Query parameters:
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode Resource Description - VNode}.
      # * *type* -- Type of operation: update or stop
      # * *async* -- Asynchronious mode, check the physical node status to know when the configuration is done (see GET /vnodes/:vnodename)
      put '/vnodes/:vnodename/?' do
        check do
          desc = {}
          desc = JSON.parse(params['desc']) if params['desc']
          case params['type']
          when 'update'
            @body = @daemon.vnode_update(CGI.unescape(params['vnodename']),desc,params['async']).first
          when 'stop'
            @body = @daemon.vnode_stop(CGI.unescape(params['vnodename']),params['async'])
          when 'remove'
            @body = @daemon.vnode_remove(CGI.unescape(params['vnodename']))
          when 'freeze'
            @body = @daemon.vnodes_freeze([CGI.unescape(params['vnodename'])],params['async'])
          when 'unfreeze'
            @body = @daemon.vnodes_unfreeze([CGI.unescape(params['vnodename'])],params['async'])
          else
            raise Lib::InvalidParameterError, params['type']
          end
        end

        return result!
      end

      # Update or stop the virtual nodes following a new description
      #
      # ==== Query parameters:
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode Resource Description - VNode}.
      # * *type* -- Type of operation: update or stop
      # * *async* -- Asynchronious mode, check the physical node status to know when the configuration is done (see GET /vnodes/:vnodename)
      put '/vnodes/?' do
        check do
          desc = params['desc'] ? JSON.parse(params['desc']) : {}
          names = params['names'] ? JSON.parse(params['names']) : nil
          case params['type']
          when 'update'
            @body = @daemon.vnode_update(names,desc,params['async'])
          when 'stop'
            @body = @daemon.vnodes_stop(names,params['async'])
          when 'remove'
            @body = @daemon.vnodes_remove(names)
          when 'freeze'
            @body = @daemon.vnodes_freeze(names,params['async'])
          when 'unfreeze'
            @body = @daemon.vnodes_unfreeze(names,params['async'])
          else
            raise Lib::InvalidParameterError, params['type']
          end
        end

        return result!
      end

      # Set up the virtual node filesystem
      #
      # ==== Query parameters:
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode_filesystem Resource Description - VFilesystem}.
      post '/vnodes/:vnodename/filesystem/?' do
        check do
          desc = {}
          desc = JSON.parse(params['desc']) if params['desc']
          @body = @daemon.vfilesystem_create(CGI.unescape(params['vnodename']),desc)
        end

        return result!
      end

      # Update the virtual node filesystem
      #
      # ==== Query parameters:
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode_filesystem Resource Description - VFilesystem}.
      put '/vnodes/:vnodename/filesystem/?' do
        check do
          desc = {}
          desc = JSON.parse(params['desc']) if params['desc']
          @body = @daemon.vfilesystem_update(CGI.unescape(params['vnodename']),desc)
        end

        return result!
      end


      # Retrieve informations about the virtual node filesystem
      get '/vnodes/:vnodename/filesystem/?' do
        check do
          @body = @daemon.vfilesystem_get(CGI.unescape(params['vnodename']))
        end

        return result!
      end

      # Get a compressed archive of the current filesystem (tgz)
      #
      # *Important*: You have to contact the physical node the vnode is hosted on directly
      get '/vnodes/:vnodename/filesystem/image/?' do
        check do
          @body = @daemon.vfilesystem_image(CGI.unescape(params['vnodename']))
          send_file(@body, :filename => "#{params['vnodename']}-fsimage.tar.gz")
        end
      end

      # Execute and get the result of a command on a virtual node
      #
      # ==== Query parameters:
      # * *command* -- The command to be executed
      #
      post '/vnodes/:vnodename/commands/?' do
        check do
          r = @daemon.vnode_execute(CGI.unescape(params['vnodename']),
                                    params['command'])
          @body = (r ? r.split("\n") : [])
        end

        return result!
      end

      # Create a new virtual interface on the targeted virtual node
      # The IP address is auto assigned to the virtual interface if not specified
      #
      # ==== Query parameters:
      # * *name* -- the name of the virtual interface (need to be unique on this virtual node)
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode_iface Resource Description - VIface}.
      post '/vnodes/:vnodename/ifaces/?' do
        check do
          desc = {}
            desc = JSON.parse(params['desc']) if params['desc']
            @body = @daemon.viface_create(CGI.unescape(params['vnodename']),params['name'],desc)
        end

        return result!
      end

      # Remove a specified virtual network interface
      delete '/vnodes/:vnodename/ifaces/:ifacename/?' do
        check do
          @body = @daemon.viface_remove(CGI.unescape(params['vnodename']),
            CGI.unescape(params['ifacename']))
        end

        return result!
      end

      # Get the description of a virtual network interface
      get '/vnodes/:vnodename/ifaces/:ifacename/?' do
        check do
          @body = @daemon.viface_get(CGI.unescape(params['vnodename']),
            CGI.unescape(params['ifacename']))
        end

        return result!
      end

      # Update a virtual network interface
      #
      # *Important*: If specified in the description, the vtraffic description is updated on-the-fly
      #
      # ==== Query parameters:
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode_iface Resource Description - VIface}.
      #
      # *Note*: Dettach/Disconnect the virtual interface if properties is empty
      put '/vnodes/:vnodename/ifaces/:ifacename/?' do
        check do
          vnodename = CGI.unescape(params['vnodename'])
          vifacename = CGI.unescape(params['ifacename'])
          desc = {}
          desc = JSON.parse(params['desc']) if params['desc']
          @body = @daemon.viface_update(vnodename,vifacename,desc)
        end

        return result!
      end

      # Retrive the traffic description on the input of a specified virtual network interface
      #
      get '/vnodes/:vnodename/ifaces/:ifacename/input/?' do
        check do
          vnodename = CGI.unescape(params['vnodename'])
          vifacename = CGI.unescape(params['ifacename'])
          @body = @daemon.vinput_get(vnodename,vifacename)
        end

        return result!
      end

      # Update the traffic description on the input of a specified virtual network interface
      #
      # *Important*: The vtraffic description is updated on-the-fly
      #
      # ==== Query parameters:
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode_traffic Resource Description - VTraffic}.
      put '/vnodes/:vnodename/ifaces/:ifacename/input/?' do
        check do
          vnodename = CGI.unescape(params['vnodename'])
          vifacename = CGI.unescape(params['ifacename'])
          desc = {}
          desc = JSON.parse(params['desc']) if params['desc']
          @body = @daemon.vinput_update(vnodename,vifacename,desc)
        end

        return result!
      end

      # Retrive the traffic description on the output of a specified virtual network interface
      #
      get '/vnodes/:vnodename/ifaces/:ifacename/output/?' do
        check do
          vnodename = CGI.unescape(params['vnodename'])
          vifacename = CGI.unescape(params['ifacename'])
          @body = @daemon.voutput_get(vnodename,vifacename)
        end

        return result!
      end

      # Update the traffic description on the output of a specified virtual network interface
      #
      # *Important*: The vtraffic description is updated on-the-fly
      #
      # ==== Query parameters:
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode_traffic Resource Description - VTraffic}.
      put '/vnodes/:vnodename/ifaces/:ifacename/output/?' do
        check do
          vnodename = CGI.unescape(params['vnodename'])
          vifacename = CGI.unescape(params['ifacename'])
          desc = {}
          desc = JSON.parse(params['desc']) if params['desc']
          @body = @daemon.voutput_update(vnodename,vifacename,desc)
        end

        return result!
      end

      # Create a new virtual cpu on the targeted virtual node.
      # By default all the virtual nodes on a same physical one are sharing available CPU resources, using this method you can allocate some cores to a virtual node and apply some limitations on them
      #
      # ==== Query parameters:
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode_cpu Resource Description - VCPU}.
      post '/vnodes/:vnodename/cpu/?' do
        check do
          desc = {}
          desc = JSON.parse(params['desc']) if params['desc']
          @body = @daemon.vcpu_create(CGI.unescape(params['vnodename']),desc)
        end

        return result!
      end

      # Remove virtual CPU of a virtual node
      delete '/vnodes/:vnodename/cpu/?' do
        check do
          @body = @daemon.vcpu_remove(CGI.unescape(params['vnodename']))
        end

        return result!
      end

      # Update the virtual CPU associated with a virtual node (can be used when the node is started)
      #
      # *Important*: The frequency description is updated on-the-fly
      #
      # ==== Query parameters:
      # * *desc* --  JSON Hash structured as described in {file:files/resources_desc.md#vnode_cpu Resource Description - VCPU}.
      put '/vnodes/:vnodename/cpu/?' do
        check do
          desc = {}
          desc = JSON.parse(params['desc']) if params['desc']
          @body = @daemon.vcpu_update(CGI.unescape(params['vnodename']),desc)
        end

        return result!
      end

      # Get the description of the virtual CPU associated with a virtual node
      get '/vnodes/:vnodename/cpu/?' do
        check do
          @body = @daemon.vcpu_get(CGI.unescape(params['vnodename']))
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
          opts = params.has_key?('opts') ? JSON.parse(params['opts']) : nil
          @body = @daemon.vnetwork_create(params['name'],params['address'],opts)
        end

        return result!
      end

      # Add a routing interface
      #
      # ==== Query parameters
      # * *address* -- the address of the interface to add in the bridge
      # * *netmask* -- the netmask of the interface to add in the bridge
      put '/vnetworks/?' do
        check do
          @body = @daemon.vnetwork_create_routing_interface(params['address'],params['netmask'])
        end

        return result!
      end

      # Delete the virtual network
      delete '/vnetworks/:vnetname/?' do
        check do
          @body = @daemon.vnetwork_remove(CGI.unescape(params['vnetname']))
        end

        return result!
      end

      # Get the description of a virtual network
      get '/vnetworks/:vnetname/?' do
        check do
          @body = @daemon.vnetwork_get(CGI.unescape(params['vnetname']))
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

      # Create a virtual route ("go from <networkname> to <destnetwork> via <gatewaynode>").
      # The virtual route is applied to all the vnodes of <networkname>.
      # This method automagically set <gatewaynode> in gateway mode (if it's not already the case) and find the right virtual interface to set the virtual route on
      #
      # ==== Query parameters:
      # * *destnetwork* -- the name of the destination network
      # * *gatewaynode* -- the name of the virtual node to use as a gateway
      #
      post '/vnetworks/:vnetname/routes/?' do
        check do
          @body = @daemon.vroute_create(
            CGI.unescape(params['vnetname']),
            params['destnetwork'],
            params['gatewaynode']
          )
        end

        return result!
      end

      # Try to create every possible virtual routes between the current
      # set of virtual nodes automagically finding and setting up
      # the gateways to use
      #
      post '/vnetworks/routes/complete/?' do
        check do
          @body = @daemon.vroute_complete()
        end

        return result!
      end

      # Get the description file of the current platform in a specified format (JSON if not specified)
      get '/vplatform' do
        check do
          @body = @daemon.vplatform_get()
        end

        return result!
      end

      # Load a configuration
      #
      # ==== Query parameters:
      # * *data* --  Data structured as described in {file:files/resources_desc.md#vplatform}.
      # * *format* -- the format of the data
      # ==== Return Content-Type:
      # +application/file+ -- The file in the requested format
      #
      # post '/vplatform/?' do
      # end

      # # (see POST /vplatform)
      # post '/' do
      # end

      ['/vplatform/?', '/'].each do |path|
        post path do
          check do
            @body = @daemon.vplatform_create(params['format'],params['data'],params['rootfs'] == '' ? nil : params['rootfs'])
          end
          
          return result!
        end
      end

      # Add a event trace to a resource
      post '/events/trace/?' do
        check do
          trace = {}
          trace = JSON.parse(params['trace']) if params['trace']
          resource_desc = {}
          resource_desc = JSON.parse(params['resource']) if params['resource']
          event_type = CGI.unescape(params['event_type'])
          @daemon.event_trace_add(resource_desc, event_type, trace)
          @body = ""
        end
      end

      # Add a event trace to a resource, but the source is a string
      post '/events/trace_string/?' do
        check do
          trace_string = CGI.unescape(params['trace_string'])
          resource_desc = JSON.parse(params['resource']) if params['resource']
          event_type = CGI.unescape(params['event_type'])
          @daemon.event_trace_string_add(resource_desc, event_type, trace_string)
          @body = ""
        end
      end

      # Add a random generated event to a resource
      post '/events/random/?' do
        check do
          generator_desc = {}
          generator_desc = JSON.parse(params['generator']) if params['generator']
          resource_desc = {}
          resource_desc = JSON.parse(params['resource']) if params['resource']
          event_type = CGI.unescape(params['event_type'])
          first_value = nil
          first_value = CGI.unescape(params['first_value']) if params['first_value']
          @daemon.event_random_add(resource_desc, event_type, generator_desc, first_value)
          @body = ""
        end
      end

      # Start the event manager
      post '/eventmanager/?' do
        check do
          @daemon.event_manager_start
          @body = ""
        end

        return result!
      end

      # Stop the event manager and clear the event list
      delete '/eventmanager/?' do
        check do
          @daemon.event_manager_stop
          @body = ""
        end
      end

      post '/peers_matrix_latencies/?' do
        check do
          vnodes = (params['vnodes'] == "") ? nil : JSON.parse(params['vnodes'])
          @body = @daemon.set_peers_latencies(vnodes, JSON.parse(params['matrix']))
        end
      end

      post '/global_etchosts/?' do
        check do
          data = params.has_key?('data') ? params['data'] : nil
          @daemon.set_global_etchosts(data)
          @body = ""
        end
      end

      post '/vnodes/:vnodename/vmem/?' do
        check do
          desc = {}
          desc = JSON.parse(params['desc']) if params['desc']
          @body = @daemon.vmem_create(params['vnodename'],desc)
        end

        return result!
      end

      post '/global_arptable/?' do
        check do
          data = params.has_key?('data') ? params['data'] : nil
          arp_file = params.has_key?('arp_file') ? params['arp_file'] : nil
          @daemon.set_global_arptable(data, arp_file)
          @body = ""
        end
      end

      post '/wait_vnodes/?' do
        check do
          opts = params.has_key?('opts') ? JSON.parse(params['opts']) : {}
          @body = @daemon.wait_vnodes(opts)
        end
        return result!
      end

      protected

      # Setting up result (auto generate JSON if @body is a {Distem::Resource})
      # @return [Array] An array of the format [@status,@headers,@body]
      # @private
      def result!
        classname = nil
        full_version = RUBY_VERSION.split('.')
        main_version = full_version[0] + '.' + full_version[1]
        case main_version
        when '1.8'
          classname = @body.class.name.split('::').last
        when '1.9','2.0','2.1'
          classname = (@body.class.name.split('::').last).to_sym
        else
          raise "Unsupported Ruby version: #{RUBY_VERSION}"
        end
        if Distem::Resource.constants.include?(classname) \
          or @body.is_a?(Resource::VIface::VTraffic) \
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
        elsif @body.is_a?(NilClass)
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


    class CoordinatorServer < Server
      set :port, 4567

      def initialize
        super
        @daemon = Daemon::DistemCoordinator.new(settings.network_mode, settings.network_interface)
      end
    end

    class PnodeServer < Server
      set :port, 4568

      def initialize
        super
        @daemon = Daemon::DistemPnode.new
      end
    end

    class ServerCoordinator < CoordinatorServer
      def initialize
        super()
      end

      def run
        ServerCoordinator.run!
      end
    end

    class ServerPnode < PnodeServer
      def run
        ServerPnode.run!
      end
    end
  end
end
