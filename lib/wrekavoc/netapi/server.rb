require 'sinatra/base'
require 'wrekavoc'

module Wrekavoc

  module NetAPI

    class Server < Sinatra::Base
      set :environment, :developpement
      set :run, true

      def initialize
        super
        @daemon_admin = Daemon::Admin.new
        @daemon_resources = Daemon::Resource.new
        @node_admin = Node::Admin.new
      end

      def run
        Server.run!
      end

      before do
        @target = params['target']
        @ret = (daemon? ? "(#{@target}) " : "")
      end

      after do
        @target = nil
        @ret = nil
      end

      post PNODE_INIT do
        if daemon?
          pnode = @daemon_resources.get_pnode(@target)
          @daemon_admin.pnode_run_server(pnode)
          sleep(1)

          cl = Client.new(@target)
          @ret += cl.pnode_init(TARGET_SELF)
        else
          @node_admin.init_node()
          @ret += "Node initilized"
        end

        return @ret
      end


      post VNODE_CREATE do
        # >>> TODO: Validate target addr ?

        if daemon?
          pnode = @daemon_resources.get_pnode(@target)
          vnode = Resource::VNode.new(pnode,params['name'],params['image'])
          @daemon_resources.add_vnode(vnode)

          cl = Client.new(@target)
          @ret += cl.vnode_create(TARGET_SELF,vnode.name,vnode.image)
        else
          @ret += "Virtual node '#{params['name']}' created"
        end

        return @ret
      end

      protected
      def daemon?
        @target != TARGET_SELF
      end
    end

  end

end
