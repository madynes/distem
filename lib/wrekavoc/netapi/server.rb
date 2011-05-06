require 'wrekavoc'
require 'sinatra/base'

module Wrekavoc

  module NetAPI

    class Server < Sinatra::Base
      set :environment, :developpement
      set :run, true
      #class MyCustomError < StandardError; end 

      def initialize
        super
        @daemon_resources = Daemon::Resource.new
        @node_config = Node::ConfigManager.new
      end

      def run
        Server.run!
      end

      #error MyCustomError do
      #  'So what happened was...' + env['sinatra.error'].message
      #end

      before do
        # >>> TODO: Validate target addr ?

        @target = params['target']
        @ret = (daemon? ? "(#{@target}) " : "")
      end

      #before %r{^(?!"#{PNODE_INIT}"$)} do
        #if daemon?
        #  pnode = @daemon_resources.get_pnode(@target)
        #  if pnode.status != Wrekavoc::Resource::PNode::STATUS_RUN
        #    raise MyCustomError, "PROUT"
        #  end
        #end
      #end

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
        # >>> TODO: Check if PNode is initialized
        # >>> TODO: Check if the image file is correct

        if daemon?
          #The current node is replaces if the name is already taken
          vnode = @daemon_resources.get_vnode(params['name'])
          @daemon_resources.destroy_vnode(vnode) if vnode

          pnode = @daemon_resources.get_pnode(@target)
          vnode = Resource::VNode.new(pnode,params['name'],params['image'])

          @daemon_resources.add_vnode(vnode)

          cl = Client.new(@target)
          @ret += cl.vnode_create(TARGET_SELF,vnode.name,vnode.image)
        else
          #The current node is replaces if the name is already taken
          vnode = @node_config.get_vnode(params['name'])
          @node_config.destroy(vnode) if vnode
          
          pnode = Resource::PNode.new(@target)
          vnode = Resource::VNode.new(pnode,params['name'],params['image'])

          @node_config.vnode_add(vnode)

          @ret += "Virtual node '#{vnode.name}' created"
        end

        return @ret
      end

      post VNODE_START do
        # >>> TODO: Check if PNode is initialized
        # >>> TODO: Check if VNode is valid

        if daemon?
          cl = Client.new(@target)
          @ret += cl.vnode_start(TARGET_SELF,params['vnode'])
        else
          vnode = @node_config.get_vnode(params['vnode'])

          @node_config.vnode_start(vnode)

          @ret += "Virtual node '#{vnode.name}' started"
        end

        return @ret
      end

      post VNODE_STOP do
        # >>> TODO: Check if PNode is initialized
        # >>> TODO: Check if VNode is valid

        if daemon?
          cl = Client.new(@target)
          @ret += cl.vnode_stop(TARGET_SELF,params['vnode'])
        else
          vnode = @node_config.get_vnode(params['vnode'])

          @node_config.vnode_stop(vnode)

          @ret += "Virtual node '#{vnode.name}' stoped"
        end

        return @ret
      end

      post VIFACE_CREATE do
        # >>> TODO: Check if PNode is initialized
        # >>> TODO: Check if viface already exists (name)
        # >>> TODO: Check if VNode is valid

        if daemon?
          vnode = @daemon_resources.get_vnode(params['vnode'])
          viface = Resource::VIface.new(params['name'],params['ip'])
          vnode.add_viface(viface)

          cl = Client.new(@target)
          @ret += cl.viface_create(TARGET_SELF,vnode.name,viface.name,viface.ip)
        else
          vnode = @node_config.get_vnode(params['vnode'])
          viface = Resource::VIface.new(params['name'],params['ip'])
          vnode.add_viface(viface)

          @node_config.vnode_configure(vnode)

          @ret += "Virtual Interface '#{viface.name}' created on '#{vnode.name}'"
        end

        return @ret
      end

      post VNODE_INFO_ROOTFS do
        # >>> TODO: Check if PNode is initialized
        # >>> TODO: Check if VNode is valid

        if daemon?
          cl = Client.new(@target)
          @ret += cl.vnode_info_rootfs(TARGET_SELF,params['vnode'])
        else
          vnode = @node_config.get_vnode(params['vnode'])
          @ret += @node_config.get_container(vnode).rootfspath
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
