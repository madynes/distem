require 'wrekavoc'
require 'sinatra/base'

module Wrekavoc

  module NetAPI

    class Server < Sinatra::Base
      set :environment, :developpement
      set :run, true

      def initialize
        super
        @daemon_resources = Daemon::Resource.new
        @node_config = Node::ConfigManager.new
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
          Daemon::Admin.pnode_run_server(pnode)
          sleep(1)

          cl = Client.new(@target)
          @ret += cl.pnode_init(TARGET_SELF)
        else
          Node::Admin.init_node()
          @ret += "Node initilized"
        end

        return @ret
      end


      post VNODE_CREATE do
        # >>> TODO: Validate target addr ?
        # >>> TODO: Check if vnode already exists (name)

        if daemon?
          pnode = @daemon_resources.get_pnode(@target)
          vnode = Resource::VNode.new(pnode,params['name'],params['image'])

          @daemon_resources.add_vnode(vnode)

          cl = Client.new(@target)
          @ret += cl.vnode_create(TARGET_SELF,vnode.name,vnode.image)
        else
          pnode = Resource::PNode.new(@target)
          vnode = Resource::VNode.new(pnode,params['name'],params['image'])

          @node_config.vnode_add(vnode)

          @ret += "Virtual node '#{params['name']}' created"
        end

        return @ret
      end

      post VIFACE_CREATE do
        # >>> TODO: Validate target addr ?
        # >>> TODO: Check if viface already exists (name)

        if daemon?
          vnode = @daemon_resources.get_vnode(params['vnode'])
          viface = Resource::VIface.new(params['name'],params['ip'])
          vnode.add_viface(viface)

          cl = Client.new(@target)
          @ret += cl.viface_create(TARGET_SELF,vnode.name,viface.name,viface.ip)
        else
          vnode = @node_config.vnode_get(params['vnode'])
          viface = Resource::VIface.new(params['name'],params['ip'])
          vnode.add_viface(viface)

          @node_config.vnode_configure(vnode)

          @ret += "Virtual Interface '#{viface.name}' created on '#{vnode.name}'"
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
