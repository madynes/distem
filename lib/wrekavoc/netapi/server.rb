require 'wrekavoc'
require 'sinatra/base'
require 'socket'
require 'ipaddress'
require 'json'

module Wrekavoc
  module NetAPI

    class Server < Sinatra::Base
      set :environment, :developpement
      set :run, true
      #class MyCustomError < StandardError; end 

      MODE_DAEMON=0
      MODE_NODE=1

      def initialize() #:nodoc:
        super
        @node_name = (ENV['HOSTNAME'] ? ENV['HOSTNAME'] : Socket::gethostname)
        @mode = settings.mode

        @node_config = Node::ConfigManager.new
        @daemon_resources = Resource::VPlatform.new if @mode == MODE_DAEMON
        @daemon_vnetlimit = Limitation::Network::Manager.new if @mode == MODE_DAEMON
      end

=begin
      error MyCustomError do
        'So what happened was...' + env['sinatra.error'].message
      end
=end
      def run #:nodoc:
        raise "Server can not be run directly, use ServerDaemon or ServerNode"
      end

      before do
        #@ret = (daemon? ? "" : "(#{@node_name}) ")
        @ret = ""
      end

      after do
        @ret = ""
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
      # <tt>application/??</tt>:: ??
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      post PNODE_INIT do
        if daemon?
          if target?
            pnode = @node_config.pnode
            pnode.status = Wrekavoc::Resource::PNode::STATUS_RUN
          else
            pnode = @daemon_resources.get_pnode_by_address(params['target'])
          end

          pnode = Wrekavoc::Resource::PNode.new(params['target']) unless pnode

          @daemon_resources.add_pnode(pnode)

          unless target?
            Daemon::Admin.pnode_run_server(pnode)
            sleep(1)

            cl = Client.new(params['target'])
            @ret += cl.pnode_init(params['target'])
          end
        end

        if target?
          Node::Admin.init_node()
          @ret += "#{JSON.pretty_generate(@node_config.pnode.to_hash)}"
        end

        return @ret
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
      # <tt>target</tt>:: the physical machine the virtual node will be created on
      # <tt>name</tt>:: the -unique- name of the virtual node to create (it will be used in a lot of methods)
      # <tt>image</tt>:: the -local- path to the file system image to be used on that node (on the physical machine)
      # 
      # == Content-Types
      # <tt>application/??</tt>:: ??
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
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

          unless target?
            cl = Client.new(params['target'])
            @ret += cl.vnode_create(params['target'],vnode.name,vnode.image)
          end
        end

        if target?
          #The current node is replaces if the name is already taken
          tmpvnode = @node_config.get_vnode(params['name'])
          @node_config.vnode_destroy(tmpvnode.name) if tmpvnode

          @node_config.vnode_add(vnode)

          @ret += "#{JSON.pretty_generate(vnode.to_hash)}"
        end

        return @ret
      end
      
      ##
      # :method: post(/vnodes/start)
      #
      # :call-seq:
      #   POST /vnodes/start
      # 
      # Start the -previously created- virtual node
      #
      # == Query parameters
      # <tt>vnode</tt>:: the name of the virtual node to be started
      #
      # == Content-Types
      # <tt>application/??</tt>:: ??
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      post VNODE_START do
        # >>> TODO: Check if PNode is initialized
        vnode = get_vnode()

        if daemon?
          unless target?
            cl = Client.new(vnode.host.address)
            @ret += cl.vnode_start(vnode.name)
          end
        end

        if target?
          @node_config.vnode_start(vnode.name)
          @ret += "#{JSON.pretty_generate(vnode.to_hash)}"
        end

        return @ret
      end

      ##
      # :method: post(/vnodes/stop)
      #
      # :call-seq:
      #   POST /vnodes/stop
      # 
      # Stop the virtual node
      #
      # == Query parameters
      # <tt>vnode</tt>:: the name of the virtual node to be stoped
      #
      # == Content-Types
      # <tt>application/??</tt>:: ??
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      post VNODE_STOP do
        # >>> TODO: Check if PNode is initialized
        vnode = get_vnode()

        if daemon?
          unless target?
            cl = Client.new(vnode.host.address)
            @ret += cl.vnode_stop(vnode.name)
          end
        end

        if target?
          @node_config.vnode_stop(vnode.name)
          @ret += "#{JSON.pretty_generate(vnode.to_hash)}"
        end

        return @ret
      end
      
      ##
      # :method: post(/vnodes/vifaces)
      #
      # :call-seq:
      #   POST /vnodes/vifaces
      # 
      # Create a new virtual interface on the targeted virtual node (without attaching it to any network -> no ip address)
      #
      # == Query parameters
      # <tt>vnode</tt>:: the name of the virtual node to create the virtual interface on
      # <tt>name</tt>:: the name of the virtual interface (need to be unique on this virtual node)
      # == Content-Types
      # <tt>application/??</tt>:: ??
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      post VIFACE_CREATE do
        # >>> TODO: Check if PNode is initialized
        # >>> TODO: Check if viface already exists (name)
        vnode = get_vnode()
        viface = Resource::VIface.new(params['name'])
        vnode.add_viface(viface)

        if daemon?
          unless target?
            cl = Client.new(vnode.host.address)
            @ret += cl.viface_create(vnode.name,viface.name)
          end
        end

        if target?
          @node_config.viface_add(viface)
          @node_config.vnode_configure(vnode.name)
          @ret += "#{JSON.pretty_generate(viface.to_hash)}"
        end

        return @ret
      end

      post VNODE_GATEWAY do
        vnode = get_vnode()

        if daemon?
          unless target?
            cl = Client.new(vnode.host.address)
            @ret += cl.vnode_gateway(vnode.name)
          end
        end

        if target?
          vnode.gateway = true
          @node_config.vnode_configure(vnode.name)

          @ret += "#{JSON.pretty_generate(vnode.to_hash)}"
        end

        return @ret
      end
      
      post VNODE_INFO_ROOTFS do
        # >>> TODO: Check if PNode is initialized
        vnode = get_vnode()

        if daemon?
          unless target?
            cl = Client.new(vnode.host.address)
            @ret += cl.vnode_info_rootfs(vnode.name)
          end
        end

        if target?
          @ret += @node_config.get_container(vnode.name).rootfspath
        end

        #non_verbose()

        return @ret
      end
      
      ##
      # :method: get(/vnodes/:name)
      #
      # :call-seq:
      #   GET /vnodes
      # 
      # Get the description of a virtual node
      #
      # == Query parameters
      # <tt>name</tt>:: the name of the virtual node
      #
      # == Content-Types
      # <tt>application/json</tt>:: JSON
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      get VNODE_INFO + '/:vnode' do
        vnode = get_vnode()
        @ret += "#{JSON.pretty_generate(vnode.to_hash)}"
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
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      get VNODE_INFO_LIST do
        # >>> TODO: Check if PNode is initialized
        
        if daemon?
            ret = {}
            @daemon_resources.pnodes.each_value do |pnode|
              unless Lib::NetTools.get_default_addr == pnode.address
                cl = Client.new(pnode.address)
                ret[pnode.address.to_s] = JSON.parse(cl.vnode_info_list())
              else
                ret[@node_config.pnode.address.to_s] = @node_config.get_vnodes_list()
              end
            end
            @ret += "#{JSON.pretty_generate(ret)}"
        else
          @ret += "#{JSON.pretty_generate(@node_config.get_vnodes_list())}"
        end

        #non_verbose()

        return @ret
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
      # <tt>application/??</tt>:: ??
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      post VNETWORK_CREATE do
        if daemon?
          # >>> TODO: Check if vnetwork already exists
          # >>> TODO: Validate ip
          vnetwork = Resource::VNetwork.new(params['address'],params['name'])
          @daemon_resources.add_vnetwork(vnetwork)

          #Add a virtual interface connected on the network
          Lib::NetTools.set_new_nic(Daemon::Admin.get_vnetwork_addr(vnetwork))

          @ret += "#{JSON.pretty_generate(vnetwork.to_hash)}"
        end

        return @ret
      end

      ##
      # :method: post(/vnetworks/vnodes/add)
      #
      # :call-seq:
      #   POST /vnetworks/vnodes/add
      # 
      # Connect a virtual node on a virtual network specifying which of it's virtual interface to use
      # The IP address is auto assigned to the virtual interface
      #
      # == Query parameters
      # <tt>vnetwork</tt>:: the name of the virtual network to connect the virtual node on
      # <tt>vnode</tt>:: the name of the virtual node to connect
      # <tt>viface</tt>:: the virtual interface to use for the connection
      #
      # == Content-Types
      # <tt>application/??</tt>:: ??
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      post VNETWORK_ADD_VNODE do
        vnode = get_vnode()

        if daemon?
          # >>> TODO: Check if vnetwork exists
          # >>> TODO: Check if viface exists
          # >>> TODO: Validate ip
          vnetwork = @daemon_resources.get_vnetwork_by_name(params['vnetwork'])
          viface = vnode.get_viface_by_name(params['viface'])
          vnetwork.add_vnode(vnode,viface)
          

          cl = Client.new(vnode.host.address)
          ret = {}
          ret['vnode'] = vnode.to_hash
          ret['vnetwork'] = vnetwork.to_hash
          ret['viface'] = JSON.parse(cl.viface_attach(vnode.name,viface.name,viface.address.to_string))
          @ret += "#{JSON.pretty_generate(ret)}"
        end

        return @ret
      end

      post VIFACE_ATTACH do
        vnode = get_vnode()
        
        if target?
          viface = vnode.get_viface_by_name(params['viface'])
          address = IPAddress::IPv4.new(params['address'])
          vnetwork = @node_config.vplatform.get_vnetwork_by_address(address.network.to_string)
          unless vnetwork
            if daemon?
              vnetwork = @daemon_resources.get_vnetwork_by_address(address.network.to_string)
            else
              vnetwork = Resource::VNetwork.new(address.network)
            end
            @node_config.vnetwork_add(vnetwork) 
          end
          viface.attach(vnetwork,address)

          @node_config.vnode_configure(vnode.name)
          @node_config.vnode_stop(vnode.name)
          @node_config.vnode_start(vnode.name)
          @ret += "#{JSON.pretty_generate(viface.to_hash)}"
        end

        #non_verbose()

        return @ret
      end


      ##
      # :method: post(/vnetworks/vroutes)
      #
      # :call-seq:
      #   POST /vnetworks/vroutes
      # 
      # Create a virtual route ("go from Net1 to Net2 via NodeGW") on a virtual node
      # (this method automagically set NodeGW as a gateway if it's not already the case
      # and find the right virtual interface to set the virtual route on)
      #
      # == Query parameters
      # <tt>networksrc</tt>:: the name of the source network
      # <tt>networkdst</tt>:: the name of the destination network
      # <tt>gatewaynode</tt>:: the name of the virtual node to use as a gateway
      # <tt>vnode</tt>:: the virtual node to set the virtual route on
      #
      # == Content-Types
      # <tt>application/??</tt>:: ??
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      post VROUTE_CREATE do
        if daemon? and !target?
          gw = @daemon_resources.get_vnode(params['gatewaynode'])
          srcnet = @daemon_resources.get_vnetwork_by_name(params['networksrc'])
          destnet = @daemon_resources.get_vnetwork_by_name(params['networkdst'])
          gwaddr = gw.get_viface_by_network(srcnet).address
        else
          gw = IPAddress::IPv4.new(params['gatewaynode'])
          gwaddr = gw
          srcnet = @node_config.vplatform.get_vnetwork_by_address(params['networksrc'])
          destnet = @node_config.vplatform.get_vnetwork_by_address(params['networkdst'])
          destnet = Resource::VNetwork.new(params['networkdst']) unless destnet
        end
        raise unless srcnet
        raise unless destnet
        vroute = Resource::VRoute.new(srcnet,destnet,gwaddr)
        srcnet.add_vroute(vroute)

        if daemon? and !target?
          cl = Client.new(gw.host.address)
          cl.vnode_gateway(gw.name)
          
          srcnet.vnodes.each_key do |vnode|
            cl = Client.new(vnode.host.address)
            cl.vroute_create(srcnet.address.to_string, \
              destnet.address.to_string,gwaddr.to_s, vnode.name)
          end
          @daemon_resources.add_vroute(vroute)
          @ret += "#{JSON.pretty_generate(vroute.to_hash)}"
        end

        if target?
          vnode = get_vnode()

          @node_config.vnode_configure(vnode.name)
          #@ret += "VRoute (#{destnet.address.to_string} via #{gwaddr.to_s}) added to #{vnode.name}"
        end

        return @ret
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
      # <tt>application/??</tt>:: ??
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      post VROUTE_COMPLETE do
        if daemon?
          i = 0
          ret = {}
          @daemon_resources.vnetworks.each_value do |srcnet|
            @daemon_resources.vnetworks.each_value do |destnet|
              next if srcnet == destnet
              gw = srcnet.get_vroute(destnet)
              if gw
                cl = Client.new(Lib::NetTools.get_default_addr())
                ret[i] = JSON.parse(cl.vroute_create(srcnet.name, destnet.name, gw.name))
                i += 1
              end
            end
          end
          @ret += "#{JSON.pretty_generate(ret)}"
        end
        return @ret
      end
      
      ##
      # :method: post(/vnodes/execute)
      #
      # :call-seq:
      #   POST /vnodes/execute
      # 
      # Execute and get the result of a command on a virtual node
      #
      # == Query parameters
      # <tt>vnode</tt>:: the name of the virtual node on which the command have to be executed
      #
      # == Content-Types
      # <tt>application/??</tt>:: ??
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # ...
      
      #
      post VNODE_EXECUTE do
        vnode = get_vnode()
        
        if daemon?
          @ret += Daemon::Admin.vnode_run(vnode,params['command'])
        end

        return @ret
      end
      
      ##
      # :method: post(/limitations/network)
      #
      # :call-seq:
      #   POST /limitations/network
      # 
      # Create a new network limitation on a specific interface of a virtual node
      #
      # == Query parameters
      # <tt>vnode</tt>:: the name of the virtual node to set the limitation on
      # <tt>viface</tt>:: the name of the virtual interface targeted
      # <tt>direction</tt>:: the direction of the limitation: INPUT or OUTPUT
      # <tt>properties</tt>:: the properties of the limitation in JSON format
      #
      # == Content-Types
      # <tt>application/??</tt>:: ??
      #
      # == Status codes
      # <tt>200</tt>:: OK
      # 
      # == Usage
      # properties sample: { "bandwidth" : {"rate" : "20mbps"}, "latency" : {"delay" : "5ms"} }
      #
      
      #
      post LIMIT_NET_CREATE do
        vnode = get_vnode()
        viface = vnode.get_viface_by_name(params['viface'])
        prophash = JSON.parse(params['properties'])
        limits = Limitation::Network::Manager.parse_limitations(vnode,viface, \
          prophash)
        
        if daemon?
          @daemon_vnetlimit.add_limitations(limits)
          unless target?
            cl = Client.new(vnode.host.address)
            @ret += cl.limit_net_create(vnode.name, viface.name, params['properties'])
          end
        end

        if target?
          @node_config.network_limitation_add(limits)
          ret = {}
          i = 0
          limits.each do |limit|
            ret[i.to_s] = limit.to_hash
            i += 1
          end

          @ret += "#{JSON.pretty_generate(ret)}"
        end

        return @ret
      end

      protected
      def daemon? #:nodoc:
        @mode == MODE_DAEMON
      end

      def target? #:nodoc:
        if params['target']
          target = Resolv.getaddress(params['target'])
        else
          vnode = get_vnode()
          target = vnode.host.address if vnode
        end
        Lib::NetTools.get_default_addr == target
      end

      def get_vnode #:nodoc:
        if daemon?
          ret = @daemon_resources.get_vnode(params['vnode'])
        else
          ret = @node_config.get_vnode(params['vnode'])
        end

        #not_found unless ret

        return ret
      end

      def get_pnode #:nodoc:
        if daemon?
          ret = @daemon_resources.get_pnode_by_address(params['target'])
        else
          ret = @node_config.pnode
        end

        return ret
      end

      def non_verbose #:nodoc:
        unless daemon?
          tmp = @ret.split
          @ret = tmp[1..tmp.length]
        end
      end
    end

    class ServerDaemon < Server #:nodoc:
      set :mode, MODE_DAEMON

      def initialize
        super()
        Lib::NetTools.set_bridge()
      end

      def run
        ServerDaemon.run!
      end
    end

    class ServerNode < Server #:nodoc:
      set :mode, MODE_NODE

      def run
        ServerNode.run!
      end
    end

  end
end
