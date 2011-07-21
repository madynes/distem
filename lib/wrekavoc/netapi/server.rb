require 'wrekavoc'
require 'sinatra/base'
require 'socket'
require 'ipaddress'
require 'json'
require 'cgi'

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
      set :verbose, true

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
        @result = []
        content_type 'application/json', :charset => 'utf-8'
      end

      not_found do
        #response.headers[HTTP_HEADER_ERR] = \
          "ServerResourceError #{request.request_method} #{request.url}"
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
      # <tt>properties</tt>:: async
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
          props = {}
          props = JSON.parse(params['properties']) if params['properties']
          ret = @daemon.pnode_init(params['target'],props)
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: delete(/pnodes/:pnodename)
      #
      # :call-seq:
      #   DELETE /pnodes/:pnodename
      # 
      # Quit wrekavoc on a physical machine (remove everything that was created)
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
      delete '/pnodes/:pnode' do
        begin 
          ret = @daemon.pnode_quit(params['pnode'])
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
          @body = ret
        end

        return result!
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: delete(/pnodes)
      #
      # :call-seq:
      #   DELETE /pnodes
      # 
      # Quit wrekavoc on all the physical machines (remove everything that was created)
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
      delete '/pnodes' do
        begin 
          ret = @daemon.pnodes_quit()
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
          @body = ret
        end

        return result!
      end
      ##
      # :method: get(/pnodes)
      #
      # :call-seq:
      #   GET /pnodes
      # 
      # Get the list of the the currently created physical nodes
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
      get '/pnodes' do
        begin
          ret = @daemon.pnodes_get()
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: delete(/vnodes/:vnodename)
      #
      # :call-seq:
      #   DELETE /vnodes/:vnodename
      # 
      # Remove the virtual node ("Cascade" removing -> remove all the vroutes it apears as gateway)
      #
      # == Query parameters
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
      delete '/vnodes/:vnode' do
        begin
          ret = @daemon.vnode_remove(URI.unescape(params['vnode']))
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
          @body = ret
        end

        return result!
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
      # <tt>properties</tt>:: target,image,async
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
          props = {}
          props = JSON.parse(params['properties']) if params['properties']
          ret = @daemon.vnode_create(params['name'],props)
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
          @body = ret
        end

        return result!
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
          ret = @daemon.vnode_get(URI.unescape(params['vnode']))
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: delete(/vnodes)
      #
      # :call-seq:
      #   DELETE /vnodes
      # 
      # Remove every virtual nodes
      #
      # == Query parameters
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
      delete '/vnodes' do
        begin
          ret = @daemon.vnodes_remove()
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
          @body = ret
        end

        return result!
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
        begin
          ret = @daemon.vnodes_get()
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
          @body = ret
        end

        return result!
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
      # <tt>status</tt>:: the status to set: "Running" or "Ready"
      # <tt>properties</tt>:: async
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
          props = {}
          props = JSON.parse(params['properties']) if params['properties']
          ret = @daemon.vnode_set_status(URI.unescape(params['vnode']),
            params['status'],props)
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: put(/vnodes/:vnodename/mode)
      #
      # :call-seq:
      #   PUT /vnodes/:vnodename/mode
      # 
      # Change the mode of a virtual node (normal or gateway)
      #
      # == Query parameters
      # <tt>mode</tt>:: "Normal" or "Gateway"
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
      put '/vnodes/:vnode/mode' do
        begin
          ret = @daemon.vnode_set_mode(URI.unescape(params['vnode']),
            params['mode'])
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
          @body = ret
        end

        return result!
      end
      
      ##
      # :method: get(/vnodes/:vnodename/filesystem)
      #
      # :call-seq:
      #   GET /vnodes/:vnodename/filesystem
      # 
      # Retrieve informations about the virtual node filesystem
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
      get '/vnodes/:vnode/filesystem' do
        begin
          ret = @daemon.vnode_filesystem_get(URI.unescape(params['vnode']))
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: get(/vnodes/:vnodename/filesystem/image)
      #
      # :call-seq:
      #   GET /vnodes/:vnodename/filesystem/image
      # 
      # Get a compressed archive of the current filesystem (tgz)
      # WARNING: You have to contact the physical node the vnode is hosted on directly
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

      get '/vnodes/:vnode/filesystem/image' do
        begin
          ret = @daemon.vnode_filesystem_image_get(URI.unescape(params['vnode']))
          send_file(ret, :filename => "#{params['vnode']}-fsimage.tar.gz")
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
        end
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
      post '/vnodes/:vnode/commands' do
        begin
          ret = @daemon.vnode_execute(URI.unescape(params['vnode']),
            params['command'])
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
          @body = ret
        end

        return result!
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
      post '/vnodes/:vnode/vifaces' do
        begin
          ret = @daemon.viface_create(URI.unescape(params['vnode']),params['name'])
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: delete(/vnodes/:vnodename/vifaces/:vifacename)
      #
      # :call-seq:
      #   DELETE /vnodes/:vnodename/vifaces/:vifacename
      # 
      # Remove the virtual interface
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
      delete '/vnodes/:vnode/vifaces/:viface' do
        begin
          ret = @daemon.viface_remove(URI.unescape(params['vnode']),
            URI.unescape(params['viface']))
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: get(/vnodes/:vnodename/vifaces/:vifacename)
      #
      # :call-seq:
      #   GET /vnodes/:vnodename/vifaces/:vifacename
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
      get '/vnodes/:vnode/vifaces/:viface' do
        begin
          ret = @daemon.viface_get(URI.unescape(params['vnode']),
            URI.unescape(params['viface']))
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: post(/vnodes/:vnodename/vcpu)
      #
      # :call-seq:
      #   POST /vnodes/:vnodename/vcpu
      # 
      # Create a new virtual cpu on the targeted virtual node.
      # By default all the virtual nodes on a same physical one are sharing available CPU resources, using this method you can allocate some cores to a virtual node and apply some limitations on them
      #
      # == Query parameters
      # <tt>corenb</tt>:: the number of cores to allocate (need to have enough free ones on the physical node)
      # <tt>frequency</tt>:: (optional) the frequency each node have to be set (need to be lesser or equal than the physical core frequency). If the frequency is included in ]0,1] it'll be interpreted as a percentage of the physical core frequency, otherwise the frequency will be set to the specified number 
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
      post '/vnodes/:vnode/vcpu' do
        begin
          ret = @daemon.vcpu_create(URI.unescape(params['vnode']),
            params['corenb'],params['frequency'])
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
          @body = ret
        end

        return result!
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: delete(/vnetworks/:vnetworkname)
      #
      # :call-seq:
      #   DELETE /vnetworks/:vnetworkname
      # 
      # Delete the virtual network
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
      delete '/vnetworks/:vnetwork' do
        begin
          ret = @daemon.vnetwork_remove(URI.unescape(params['vnetwork']))
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
          @body = ret
        end

        return result!
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
          ret = @daemon.vnetwork_get(URI.unescape(params['vnetwork']))
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: delete(/vnetworks)
      #
      # :call-seq:
      #   DELETE /vnetworks
      # 
      # Delete every virtual networks
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
      delete '/vnetworks' do
        begin
          ret = @daemon.vnetworks_remove()
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: get(/vnetworks)
      #
      # :call-seq:
      #   GET /vnetworks
      # 
      # Get the list of the the currently created virtual networks
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
      get '/vnetworks' do
        begin
          ret = @daemon.vnetworks_get()
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: put(/vnodes/:vnodename/vifaces/:vifacename)
      #
      # :call-seq:
      #   PUT /vnodes/:vnodename/vifaces/:vifacename
      # 
      # Connect a virtual node on a virtual network specifying which of it's virtual interface to use
      # The IP address is auto assigned to the virtual interface
      # Dettach the virtual interface if properties is empty
      # You can change the limitations on the fly specifying only the limitation property
      #
      # == Query parameters
      # <tt>properties</tt>:: the address or the vnetwork to connect the virtual interface with (JSON, 'address' or 'vnetwork'), the limitations to apply on the interface (JSON, 'limitation', INPUT/OUTPUT/FULLDUPLEX)
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
      # properties['limitation'] sample: { "OUTPUT" : { "bandwidth" : {"rate" : "20mbps"}, "latency" : {"delay" : "5ms"} } }
      
      put '/vnodes/:vnode/vifaces/:viface' do 
        begin
          vnodename = URI.unescape(params['vnode'])
          vifacename = URI.unescape(params['viface'])
          props = JSON.parse(params['properties']) if params['properties']
          if props and !props.empty?
            if (!props['address'] or props['address'].empty?) \
             and (!props['vnetwork'] or  props['vnetwork'].empty?) \
             and (props['limitation'] and !props['limitation'].empty?)
              ret = @daemon.viface_configure_limitations(vnodename,
                vifacename,props['limitation'])
            else
              ret = @daemon.viface_attach(vnodename,vifacename,props)
            end
          else
            ret = @daemon.viface_detach(vnodename,vifacename)
          end
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
          @body = ret
        end

        return result!
      end


      ##
      # :method: post(/vnetworks/:networkname/vroutes)
      #
      # :call-seq:
      #   POST /vnetworks/:networkname/vroutes
      # 
      # Create a virtual route ("go from <networkname> to <destnetwork> via <gatewaynode>").
      # The virtual route is applied to all the vnodes of <networkname>.
      # This method automagically set <gatewaynode> in gateway mode (if it's not already the case) and find the right virtual interface to set the virtual route on
      #
      # == Query parameters
      # <tt>destnetwork</tt>:: the name of the destination network
      # <tt>gatewaynode</tt>:: the name of the virtual node to use as a gateway
      # Deprecated: <tt>vnode</tt>:: the virtual node to set the virtual route on (optional)
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
      post '/vnetworks/:vnetwork/vroutes' do
        begin
          ret = @daemon.vroute_create(
            URI.unescape(params['vnetwork']),
            params['destnetwork'],
            params['gatewaynode'], params['vnode'] 
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
          @body = ret
        end

        return result!
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
      post '/vnetworks/vroutes/complete' do
        begin
          ret = @daemon.vroute_complete()
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: get(/vplatform/:format)
      #
      # :call-seq:
      #   GET /vplatform/:format
      # 
      # Get the description file of the current platform in a specified format (JSON if not specified)
      #
      # == Query parameters
      #
      # == Content-Types
      # <tt>application/file</tt>:: The file in the requested format
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
      get '/vplatform/:format' do
        begin
          ret = @daemon.vplatform_get(params['format'])
          # >>> TODO: put the right format
          #send_file(ret, :filename => "vplatform")
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
          @body = ret
        end

        return result!
      end

      ##
      # :method: post(/vplatform)
      #
      # :call-seq:
      #   POST /vplatform
      # 
      # Load a configuration
      #
      # == Query parameters
      # <tt>data</tt>:: data to be applied
      # <tt>format</tt>:: the format of the data
      #
      # == Content-Types
      # <tt>application/file</tt>:: The file in the requested format
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
      post '/vplatform' do
        begin
          ret = @daemon.vplatform_create(params['format'],params['data'])
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
          @body = ret
        end

        return result!
      end
      
      protected

      def result! #:nodoc:
        classname = @body.class.name.split('::').last
        if Wrekavoc::Resource.constants.include?(classname) \
          or Wrekavoc::Limitation::Network.constants.include?(classname) \
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
