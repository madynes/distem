require 'wrekavoc'
require 'sinatra/base'
require 'socket'

module Wrekavoc
  module NetAPI

    class Server < Sinatra::Base
      set :environment, :developpement
      set :run, true
      #class MyCustomError < StandardError; end 

      MODE_DAEMON=0
      MODE_NODE=1

      def initialize()
        super
        @node_name = (ENV['HOSTNAME'] ? ENV['HOSTNAME'] : Socket::gethostname)
        @mode = settings.mode

        @node_config = Node::ConfigManager.new
        @daemon_resources = Daemon::Resource.new if @mode == MODE_DAEMON
      end

      #error MyCustomError do
      #  'So what happened was...' + env['sinatra.error'].message
      #end

      def run
        raise "Server can not be run directly, use ServerDaemon or ServerNode"
      end

      before do
        # >>> TODO: Validate target addr ?

        @ret = (daemon? ? "" : "(#{@node_name}) ")
      end

      #before %r{^(?!"#{PNODE_INIT}"$)} do
        #if daemon?
        #  pnode = @daemon_resources.get_pnode(params['target'])
        #  if pnode.status != Wrekavoc::Resource::PNode::STATUS_RUN
        #    raise MyCustomError, "PROUT"
        #  end
        #end
      #end

      after do
        @ret = nil
      end

      post PNODE_INIT do
        if daemon?
          pnode = @daemon_resources.get_pnode_by_address(params['target'])
          pnode = Wrekavoc::Resource::PNode.new(params['target']) unless pnode

          @daemon_resources.add_pnode(pnode)

          Daemon::Admin.pnode_run_server(pnode)
          sleep(1)

          cl = Client.new(params['target'])
          @ret += cl.pnode_init(params['target'])
        end

        if target?
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

          pnode = @daemon_resources.get_pnode_by_address(params['target'])
          vnode = Resource::VNode.new(pnode,params['name'],params['image'])

          @daemon_resources.add_vnode(vnode)

          cl = Client.new(params['target'])
          @ret += cl.vnode_create(params['target'],vnode.name,vnode.image)
        end

        if target?
          #The current node is replaces if the name is already taken
          vnode = @node_config.get_vnode(params['name'])
          @node_config.destroy(vnode) if vnode
          
          #pnode = Resource::PNode.new(params['target'])
          vnode = Resource::VNode.new(@node_config.pnode,params['name'], \
            params['image'])

          @node_config.vnode_add(vnode)

          @ret += "Virtual node '#{vnode.name}' created"
        end

        return @ret
      end

      post VNODE_START do
        # >>> TODO: Check if PNode is initialized
        vnode = get_vnode()

        if daemon?
          vnode = @daemon_resources.get_vnode(params['vnode'])

          cl = Client.new(vnode.host.address)
          @ret += cl.vnode_start(vnode.name)
        end

        if target?
          vnode = @node_config.get_vnode(params['vnode'])

          @node_config.vnode_start(vnode)

          @ret += "Virtual node '#{vnode.name}' started"
        end

        return @ret
      end

      post VNODE_STOP do
        # >>> TODO: Check if PNode is initialized
        vnode = get_vnode()

        if daemon?
          cl = Client.new(vnode.host.address)
          @ret += cl.vnode_stop(vnode.name)
        end

        if target?
          @node_config.vnode_stop(vnode)
          @ret += "Virtual node '#{vnode.name}' stoped"
        end

        return @ret
      end

      post VIFACE_CREATE do
        # >>> TODO: Check if PNode is initialized
        # >>> TODO: Check if viface already exists (name)
        vnode = get_vnode()

        if daemon?
          viface = Resource::VIface.new(params['name'],params['ip'])
          vnode.add_viface(viface)

          cl = Client.new(vnode.host.address)
          @ret += cl.viface_create(vnode.name,viface.name,viface.ip)
        end

        if target?
          viface = Resource::VIface.new(params['name'],params['ip'])
          vnode.add_viface(viface)

          @node_config.vnode_configure(vnode)

          @ret += "Virtual Interface '#{viface.name}' created on '#{vnode.name}'"
        end

        return @ret
      end

      post VNODE_INFO_ROOTFS do
        # >>> TODO: Check if PNode is initialized
        vnode = get_vnode()

        if daemon?
          cl = Client.new(vnode.host.address)
          @ret += cl.vnode_info_rootfs(vnode.name)
        end

        if target?
          @ret += @node_config.get_container(vnode).rootfspath
        end

        return @ret
      end

      protected
      def daemon?
        @mode == MODE_DAEMON
      end

      def target?
        if params['target']
          target = Resolv.getaddress(params['target'])
        else
          vnode = get_vnode()
          target = vnode.host.address if vnode
        end
        Node::Admin.get_default_addr == target
      end

      def get_vnode()
          if daemon?
            ret = @daemon_resources.get_vnode(params['vnode'])
          else
            ret = @node_config.get_vnode(params['vnode'])
          end

          #not_found unless ret

          return ret
      end
    end

    class ServerDaemon < Server
      set :mode, MODE_DAEMON

      def run
        ServerDaemon.run!
      end
    end

    class ServerNode < Server
      set :mode, MODE_NODE

      def run
        ServerNode.run!
      end
    end

  end
end
