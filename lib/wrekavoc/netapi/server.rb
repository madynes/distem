require 'wrekavoc'
require 'sinatra/base'
require 'socket'
require 'ipaddress'

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
        @ret = (daemon? ? "" : "(#{@node_name}) ")
      end

      after do
        @ret = ""
      end

      post PNODE_INIT do
        if daemon?
          if target?
            pnode = @node_config.pnode
          else
            pnode = @daemon_resources.get_pnode_by_address(params['target'])
          end

          pnode = Wrekavoc::Resource::PNode.new(params['target']) unless pnode
          pnode.status = Wrekavoc::Resource::PNode::STATUS_RUN

          @daemon_resources.add_pnode(pnode)

          if !target?
            Daemon::Admin.pnode_run_server(pnode)
            sleep(1)

            cl = Client.new(params['target'])
            @ret += cl.pnode_init(params['target'])
          end
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

        pnode = get_pnode()
        vnode = Resource::VNode.new(pnode,params['name'],params['image'])

        if daemon?
          #The current node is replaces if the name is already taken
          vnodetmp = @daemon_resources.get_vnode(params['name'])
          @daemon_resources.destroy_vnode(vnodetmp.name) if vnodetmp

          @daemon_resources.add_vnode(vnode)

          if !target?
            cl = Client.new(params['target'])
            @ret += cl.vnode_create(params['target'],vnode.name,vnode.image)
          end
        end

        if target?
          #The current node is replaces if the name is already taken
          tmpvnode = @node_config.get_vnode(params['name'])
          @node_config.destroy(tmpvnode.name) if tmpvnode

          @node_config.vnode_add(vnode)

          @ret += "Virtual node '#{vnode.name}' created"
        end

        return @ret
      end

      post VNODE_START do
        # >>> TODO: Check if PNode is initialized
        vnode = get_vnode()

        if daemon?
          if !target?
            cl = Client.new(vnode.host.address)
            @ret += cl.vnode_start(vnode.name)
          end
        end

        if target?
          @node_config.vnode_start(vnode.name)
          @ret += "Virtual node '#{vnode.name}' started"
        end

        return @ret
      end

      post VNODE_STOP do
        # >>> TODO: Check if PNode is initialized
        vnode = get_vnode()

        if daemon?
          if !target?
            cl = Client.new(vnode.host.address)
            @ret += cl.vnode_stop(vnode.name)
          end
        end

        if target?
          @node_config.vnode_stop(vnode.name)
          @ret += "Virtual node '#{vnode.name}' stoped"
        end

        return @ret
      end

      post VIFACE_CREATE do
        # >>> TODO: Check if PNode is initialized
        # >>> TODO: Check if viface already exists (name)
        vnode = get_vnode()
        viface = Resource::VIface.new(params['name'])
        vnode.add_viface(viface)

        if daemon?
          if !target?
            cl = Client.new(vnode.host.address)
            @ret += cl.viface_create(vnode.name,viface.name)
          end
        end

        if target?
          @node_config.vnode_configure(vnode.name)

          @ret += "Virtual Interface '#{viface.name}' created on '#{vnode.name}'"
        end

        return @ret
      end

      post VNODE_INFO_ROOTFS do
        # >>> TODO: Check if PNode is initialized
        vnode = get_vnode()

        if daemon?
          if !target?
            cl = Client.new(vnode.host.address)
            @ret += cl.vnode_info_rootfs(vnode.name)
          end
        end

        if target?
          @ret += @node_config.get_container(vnode.name).rootfspath
        end

        non_verbose()

        return @ret
      end

      post VNETWORK_CREATE do
        if daemon?
          # >>> TODO: Check if vnetwork already exists
          # >>> TODO: Validate ip
          vnetwork = Resource::VNetwork.new(params['name'],params['address'])
          @daemon_resources.add_vnetwork(vnetwork)
          @ret = "VNetwork #{vnetwork.name}(#{vnetwork.address.to_string}) created"
        end

        return @ret
      end

      post VNETWORK_ADD_VNODE do
        vnode = get_vnode()

        if daemon?
          # >>> TODO: Check if vnetwork exists
          # >>> TODO: Check if viface exists
          # >>> TODO: Validate ip
          vnetwork = @daemon_resources.get_vnetwork(params['vnetwork'])
          viface = vnode.get_viface(params['viface'])
          vnetwork.add_vnode(vnode,viface)
          

          cl = Client.new(vnode.host.address)
          @ret += cl.viface_attach(vnode.name,viface.name,viface.address.to_string)
          @ret += "\nVNode #{vnode.name} connected on #{vnetwork.name} with #{viface.name}(#{viface.address.to_s})"
        end

        return @ret
      end

      post VIFACE_ATTACH do
        vnode = get_vnode()
        
        if target?
          viface = vnode.get_viface(params['viface'])
          address = IPAddress::IPv4.new(params['address'])
          viface.attach(address.network,address)

          @node_config.vnode_configure(vnode.name)

          @ret += "VIface #{viface.name} set on #{vnode.name} with #{viface.address.to_string}"
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

      def get_vnode
        if daemon?
          ret = @daemon_resources.get_vnode(params['vnode'])
        else
          ret = @node_config.get_vnode(params['vnode'])
        end

        #not_found unless ret

        return ret
      end

      def get_pnode
        if daemon?
          ret = @daemon_resources.get_pnode_by_address(params['target'])
        else
          ret = @node_config.pnode
        end

        return ret
      end

      def non_verbose
        tmp = @ret.split
        @ret = tmp[1..tmp.length]
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
