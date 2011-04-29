require 'sinatra/base'
require 'wrekavoc/wrekanetapi/netapi'
require 'wrekavoc/wrekanetapi/client'
require 'wrekavoc/wrekad/resource'
require 'wrekavoc/wrekad/admin'
require 'wrekavoc/wrekalib/pnode'

module Wrekavoc

  module NetAPI

    class Server < Sinatra::Base
      set :environment, :developpement
      set :run, true

      def initialize()
        super()
        @daemon_admin = Daemon::Admin.new
        @daemon_resources = Daemon::Resource.new
      end

      def daemon?
        @target != TARGET_SELF
      end

      before do
        @target = params['target']
        @ret = (daemon? ? "(#{@target}) " : "")
      end

      after do
        @target = nil
        @ret = nil
      end

      post VNODE_CREATE do
        # >>> TODO: Validate target addr ?

        if daemon?
          pnode = @daemon_resources.get_pnode(@target)
          vnode = VNode.new(pnode,params['name'])
          @daemon_resources.add_vnode(vnode)

          @daemon_admin.pnode_run_server(pnode)

          cl = Client.new(@target)
          @ret += cl.vnode_create(TARGET_SELF,vnode.name)
        else
          @ret += "Virtual node '#{params['name']}' created"
        end

        return @ret
      end

      Server.run!
    end

  end

end
