require 'wrekavoc'
require 'socket'
require 'ipaddress'
require 'json'

module Wrekavoc
  module Daemon

    class WrekaDaemon
      MODE_DAEMON=0
      MODE_NODE=1

      # >>> TODO: To be removed
      attr_reader :daemon_resources, :daemon_vnetlimit, :node_config

      def initialize(mode=MODE_NODE)
        @node_name = Socket::gethostname
        @mode = mode

        @node_config = Node::ConfigManager.new

        if @mode == MODE_DAEMON
          @daemon_resources = Resource::VPlatform.new
          @daemon_vnetlimit = Limitation::Network::Manager.new
        end
      end

      def pnode_init(target)
        if daemon?
          if target?(target)
            pnode = @node_config.pnode
            pnode.status = Wrekavoc::Resource::PNode::STATUS_RUN
          else
            pnode = @daemon_resources.get_pnode_by_address(target)
          end

          pnode = Resource::PNode.new(target) unless pnode

          @daemon_resources.add_pnode(pnode)

          unless target?(target)
            Admin.pnode_run_server(pnode)
            sleep(1)

            cl = NetAPI::Client.new(target)
            ret = cl.pnode_init()
          end
        end

        if target?(target)
          Node::Admin.init_node()
          ret = @node_config.pnode.to_hash
        end

        return ret
      end

      def vnode_create(name,properties)
        # >>> TODO: Check if PNode is initialized
        # >>> TODO: Check if the image file is correct

        if daemon?
          if properties['target']
            pnode = @daemon_resources.get_pnode_by_address(properties['target'])
          else
            pnode = @daemon_resources.get_pnode_randomly()
            properties['target'] = pnode.address.to_s
          end
        else
          pnode = @node_config.pnode
        end

        raise unless pnode
        raise unless properties['image']

        vnode = Resource::VNode.new(pnode,name,properties['image'])

        if daemon?
          #The current node is replaces if the name is already taken
          vnodetmp = @daemon_resources.get_vnode(vnode.name)
          @daemon_resources.destroy_vnode(vnodetmp.name) if vnodetmp

          @daemon_resources.add_vnode(vnode)

          unless target?(properties['target'])
            cl = NetAPI::Client.new(pnode.address.to_s)
            ret = JSON.parse(cl.vnode_create(vnode.name,properties.to_json))
          end
        end

        if target?(properties['target'])
          #The current node is replaces if the name is already taken
          tmpvnode = @node_config.get_vnode(vnode.name)
          @node_config.vnode_destroy(tmpvnode.name) if tmpvnode

          @node_config.vnode_add(vnode)

          ret = vnode.to_hash
        end

        return ret
      end

      def vnode_start(name)
        # >>> TODO: Check if PNode is initialized
        # >>> TODO: Check if VNode exists
        vnode = get_vnode(name)

        raise unless vnode

        if daemon?
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            ret = JSON.parse(cl.vnode_start(vnode.name))
          end
        end

        if target?(vnode)
          @node_config.vnode_start(vnode.name)
          ret = vnode.to_hash
        end

        return ret
      end

      def vnode_stop(name)
        # >>> TODO: Check if PNode is initialized
        # >>> TODO: Check if VNode exists
        vnode = get_vnode()

        raise unless vnode

        if daemon?
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            ret = JSON.parse(cl.vnode_stop(vnode.name))
          end
        end

        if target?(vnode)
          @node_config.vnode_stop(vnode.name)
          ret = vnode.to_hash
        end

        return ret
      end


      def viface_create(vnodename,vifacename)
        # >>> TODO: Check if VNode exists
        # >>> TODO: Check if viface already exists (name)
        vnode = get_vnode(vnodename)
        raise unless vnode

        viface = Resource::VIface.new(vifacename)
        vnode.add_viface(viface)

        if daemon?
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            ret = JSON.parse(cl.viface_create(vnode.name,viface.name))
          end
        end

        if target?(vnode)
          @node_config.viface_add(viface)
          @node_config.vnode_configure(vnode.name)
          ret = viface.to_hash
        end

        return ret
      end

      def vnode_gateway(name)
        # >>> TODO: Check if VNode exists
        vnode = get_vnode(name)

        raise unless vnode

        if daemon?
          unless target?(vnode)
            cl = Client.new(vnode.host.address)
            ret = JSON.parse(cl.vnode_gateway(vnode.name))
          end
        end

        if target?(vnode)
          vnode.gateway = true
          @node_config.vnode_configure(vnode.name)

          ret = vnode.to_hash
        end

        return ret
      end

      def vnode_info(name)
        # >>> TODO: Check if VNode exists
        vnode = get_vnode(name)

        return vnode.to_hash
      end

      def vnode_info_rootfs(name)
        # >>> TODO: Check if VNode exists
        vnode = get_vnode(name)

        raise unless vnode

        if daemon?
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            ret = cl.vnode_info_rootfs(vnode.name)
          end
        end

        if target?(vnode)
          ret = @node_config.get_container(vnode.name).rootfspath
        end

        return ret
      end

      def vnode_info_list()
        # >>> TODO: Check if PNode is initialized
        
        if daemon?
            ret = {}
            @daemon_resources.pnodes.each_value do |pnode|
              unless Lib::NetTools.get_default_addr == pnode.address
                cl = NetAPI::Client.new(pnode.address)
                ret[pnode.address.to_s] = JSON.parse(cl.vnode_info_list())
              else
                ret[@node_config.pnode.address.to_s] = @node_config.get_vnodes_list()
              end
            end
        else
          ret = @node_config.get_vnodes_list()
        end

        return ret
      end

      def vnode_execute(vnodename,command)
        ret = {}
        if daemon?
          # >>> TODO: check if vnode exists
          vnode = get_vnode(vnodename)

          raise unless vnode

          ret['command'] = command
          ret['result'] = Daemon::Admin.vnode_run(vnode,params['command'])
        end

        return ret
      end

      def vnetwork_create(name,address)
        ret = {}
        if daemon?
          # >>> TODO: Check if vnetwork already exists
          # >>> TODO: Validate ip
          vnetwork = Resource::VNetwork.new(address,name)
          @daemon_resources.add_vnetwork(vnetwork)

          #Add a virtual interface connected on the network
          Lib::NetTools.set_new_nic(Daemon::Admin.get_vnetwork_addr(vnetwork))

          ret = vnetwork.to_hash
        end

        return ret
      end

      def vnetwork_add_vnode(vnetworkname,vnodename,vifacename)
        ret = {}

        if daemon?
          # >>> TODO: Check if vnetwork exists
          # >>> TODO: Check if VNode exists
          # >>> TODO: Check if viface exists
          # >>> TODO: Validate ip
          vnode = get_vnode(vnodename)
          vnetwork = @daemon_resources.get_vnetwork_by_name(vnetworkname)
          viface = vnode.get_viface_by_name(vifacename)

          raise unless vnetwork
          raise unless vnode
          raise unless viface

          vnetwork.add_vnode(vnode,viface)

          cl = NetAPI::Client.new(vnode.host.address)
          ret['vnode'] = vnode.to_hash
          ret['vnetwork'] = vnetwork.to_hash
          ret['viface'] = JSON.parse( \
            cl.viface_attach(vnode.name,viface.name,viface.address.to_string) \
          )
        end

        return ret
      end

      def viface_attach(vnodename,vifacename,vifaceaddress)
        ret = {}

        vnode = get_vnode(vnodename)
        if target?(vnode)
          # >>> TODO: Check if VNode exists
          # >>> TODO: Check if VIface exists
          viface = vnode.get_viface_by_name(vifacename)

          raise unless vnode
          raise unless viface

          address = IPAddress::IPv4.new(vifaceaddress)
          vnetwork = @node_config.vplatform.get_vnetwork_by_address(address.network.to_string)

          #Networks are not systematically created on every pnode
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

          ret = viface.to_hash
        end

        return ret
      end

      def vroute_create(networksrc,networkdst,nodegw,vnodename=nil)
        vnode = get_vnode(vnodename)
        if daemon? and !target?(vnode)
          gw = @daemon_resources.get_vnode(nodegw)
          srcnet = @daemon_resources.get_vnetwork_by_name(networksrc)
          destnet = @daemon_resources.get_vnetwork_by_name(networkdst)
          gwaddr = gw.get_viface_by_network(srcnet).address
        else
          gw = IPAddress::IPv4.new(nodegw)
          gwaddr = gw
          srcnet = @node_config.vplatform.get_vnetwork_by_address(networksrc)
          destnet = @node_config.vplatform.get_vnetwork_by_address(networkdst)
          destnet = Resource::VNetwork.new(networkdst) unless destnet
        end

        raise unless srcnet
        raise unless destnet

        vroute = Resource::VRoute.new(srcnet,destnet,gwaddr)
        srcnet.add_vroute(vroute)

        if daemon? and !target?(vnode)
          cl = NetAPI::Client.new(gw.host.address)
          cl.vnode_gateway(gw.name)
          
          srcnet.vnodes.each_key do |vnode|
            cl = NetAPI::Client.new(vnode.host.address)
            cl.vroute_create(srcnet.address.to_string, \
              destnet.address.to_string,gwaddr.to_s, vnode.name)
          end
          @daemon_resources.add_vroute(vroute)
          ret = vroute.to_hash
        end

        if target?(vnode)
          @node_config.vnode_configure(vnode.name)
        end

        return ret
      end

      def vroute_complete()
        ret = {}

        if daemon?
          i = 0
          ret = {}
          @daemon_resources.vnetworks.each_value do |srcnet|
            @daemon_resources.vnetworks.each_value do |destnet|
              next if srcnet == destnet
              gw = srcnet.get_vroute(destnet)
              if gw
                ret[i] = vroute_create(srcnet.name, destnet.name,gw.name)
                i += 1
              end
            end
          end
        end

        return ret
      end

      def limit_net_create(vnodename,vifacename,properties)
        vnode = get_vnode(vnodename)
        raise unless vnode
        viface = vnode.get_viface_by_name(vifacename)
        raise unless viface

        limits = Limitation::Network::Manager.parse_limitations(vnode,viface, \
          properties)
        
        if daemon?
          @daemon_vnetlimit.add_limitations(limits)
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            ret = JSON.parse( \
              cl.limit_net_create(vnode.name,viface.name,properties.to_json) \
            )
          end
        end

        if target?(vnode)
          @node_config.network_limitation_add(limits)
          i = 0
          ret = {}
          limits.each do |limit|
            ret[i.to_s] = limit.to_hash
            i += 1
          end
        end

        return ret
      end

      protected
      
      def daemon? #:nodoc:
        @mode == MODE_DAEMON
      end

      def target?(param) #:nodoc:
        ret = false
        if daemon?
          if param.is_a?(Resource::VNode)
            target = param.host.address.to_s
          elsif param.is_a?(String)
            begin
              target = Resolv.getaddress(param)
            rescue Resolv::ResolvError
              raise Lib::InvalidParameterError, param
            end
          end
          ret = (Lib::NetTools.get_default_addr == target)
        else
          ret = true
        end
        return ret
      end

      def get_vnode(name)
        if daemon?
          ret = @daemon_resources.get_vnode(name)
        else
          ret = @node_config.get_vnode(name)
        end

        return ret
      end
    end

  end
end
