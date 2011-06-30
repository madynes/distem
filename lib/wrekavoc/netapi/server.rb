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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          ret = @daemon.vnode_remove(params['vnode'])
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          ret = @daemon.vnode_create(params['name'], 
            JSON.parse(params['properties']) 
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          ret = @daemon.vnode_set_mode(params['vnode'],params['mode'])
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
        end

        return result!
      end
      
      post '/vnodes/infos/rootfs' do
        ret = @daemon.vnode_info_rootfs(params['vnode'])
        return ret
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
          ret = @daemon.vnode_execute(params['vnode'],params['command'])
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          ret = @daemon.viface_create(params['vnode'],params['name'])
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          ret = @daemon.viface_remove(params['vnode'],params['viface'])
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          ret = @daemon.viface_get(params['vnode'],params['viface'])
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          ret = @daemon.vnetwork_remove(params['vnetwork'])
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          props = JSON.parse(params['properties']) if params['properties']
          if props and !props.empty?
            ret = @daemon.viface_attach(params['vnode'],params['viface'],props)
          else
            ret = @daemon.viface_detach(params['vnode'],params['viface'])
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
            params['vnetwork'],
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
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
          @body = (ret.is_a?(Hash) or ret.is_a?(Array) ? ret : ret.to_hash)
        end

        return result!
      end
      
      protected

      def result! #:nodoc:
          if @body.is_a?(Array) or @body.is_a?(Hash)
            tmpbody = @body
            begin
              @body = JSON.pretty_generate(@body)
            rescue JSON::GeneratorError
              @body = tmpbody
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
