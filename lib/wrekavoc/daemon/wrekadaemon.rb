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
        begin
        if daemon?
          pnode = @daemon_resources.get_pnode_by_address(target)
          pnode = Resource::PNode.new(target) unless pnode

          @daemon_resources.add_pnode(pnode)
          @node_config.pnode = pnode

          unless target?(target)
            Admin.pnode_run_server(pnode)
            sleep(1)

            cl = NetAPI::Client.new(target)
            ret = cl.pnode_init()
            pnode.status = Resource::PNode::STATUS_RUN
          end
        end

        if target?(target)
          Node::Admin.init_node()
          @node_config.pnode.status = Wrekavoc::Resource::PNode::STATUS_RUN
          ret = @node_config.pnode.to_hash
        end

        return ret
      rescue Lib::AlreadyExistingResourceError
        raise
      rescue Exception
        destroy(pnode) if pnode
        raise
      end

      end

      def vnode_create(name,properties)
      begin
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

        #Checking args
        if pnode
          raise Lib::UnintializedResourceError, pnode.address.to_s \
            unless pnode.status == Resource::PNode::STATUS_RUN
        else
          hostname = properties['target']
          raise Lib::ResourceNotFoundError, (hostname ? hostname : 'Any')
        end
        raise Lib::MissingParameterError, "image" unless properties['image']

        #Create the resource
        vnode = Resource::VNode.new(pnode,name,properties['image'])

        if daemon?
          @daemon_resources.add_vnode(vnode)

          unless target?(pnode.address.to_s)
            cl = NetAPI::Client.new(pnode.address.to_s)
            ret = cl.vnode_create(vnode.name,properties.to_json)
          end
        end

        if target?(pnode.address.to_s)
          @node_config.vnode_add(vnode)

          ret = vnode.to_hash
        end

        return ret

      rescue Lib::AlreadyExistingResourceError
        raise
      rescue Exception
        destroy(vnode) if vnode
        raise
      end

      end

      def vnode_start(name)
        vnode = get_vnode(name)

        if daemon?
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            ret = cl.vnode_start(vnode.name)
          end
        end

        if target?(vnode)
          @node_config.vnode_start(vnode.name)
          ret = vnode.to_hash
        end

        return ret
      end

      def vnode_stop(name)
        vnode = get_vnode(name)

        if daemon?
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            ret = cl.vnode_stop(vnode.name)
          end
        end

        if target?(vnode)
          @node_config.vnode_stop(vnode.name)
          ret = vnode.to_hash
        end

        return ret
      end


      def viface_create(vnodename,vifacename)
      begin
        vnode = get_vnode(vnodename)

        viface = Resource::VIface.new(vifacename)
        vnode.add_viface(viface)

        if daemon?
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            ret = cl.viface_create(vnode.name,viface.name)
          end
        end

        if target?(vnode)
          @node_config.viface_add(viface)
          @node_config.vnode_configure(vnode.name)
          ret = viface.to_hash
        end

        return ret

      rescue Lib::AlreadyExistingResourceError
        raise
      rescue Exception
        vnode.remove_iface(viface) if vnode and viface
        raise
      end
      end

      def vnode_gateway(name)
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
      begin
        ret = {}
        if daemon?
          vnetwork = Resource::VNetwork.new(address,name)
          @daemon_resources.add_vnetwork(vnetwork)

          #Add a virtual interface connected on the network
          Lib::NetTools.set_new_nic(Daemon::Admin.get_vnetwork_addr(vnetwork))

          ret = vnetwork.to_hash
        end

        return ret

      rescue Lib::AlreadyExistingResourceError
        raise
      rescue Exception
        destroy(vnetwork) if vnetwork
        raise
      end
      end

      def viface_attach(vnodename,vifacename,properties)
      begin
        ret = {}

        vnode = get_vnode(vnodename)
        viface = vnode.get_viface_by_name(vifacename)

        raise Lib::ResourceNotFoundError, vifacename unless viface
        raise Lib::MissingParameterError, 'address|vnetwork' \
          unless (properties['address'] or properties['vnetwork'])

        if daemon?
          if properties['address']
            begin
              address = IPAddress.parse(properties['address'])
            rescue ArgumentError
              raise Lib::InvalidParameterError, properties['address']
            end
            prop = properties['address']
            vnetwork = @daemon_resources.get_vnetwork_by_address(prop)
          elsif properties['vnetwork']
            prop = properties['vnetwork']
            vnetwork = @daemon_resources.get_vnetwork_by_name(prop)
          end

          raise Lib::ResourceNotFoundError, prop unless vnetwork

          if properties['address']
            vnetwork.add_vnode(vnode,viface,address)
          else
            vnetwork.add_vnode(vnode,viface)
          end

          properties['address'] = viface.address.to_string

          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            ret = cl.viface_attach(vnode.name,viface.name,
                { 'address' => properties['address'] }
            )
          end
        end

        if target?(vnode)
          raise Lib::MissingParameterError, 'address' unless properties['address']
          begin
            address = IPAddress.parse(properties['address'])
          rescue ArgumentError
            raise Lib::InvalidParameterError, properties['address']
          end
          vnetwork = @node_config.vplatform.get_vnetwork_by_address(address)

          #Networks are not systematically created on every pnode
          unless vnetwork
            if daemon?
              vnetwork = @daemon_resources.get_vnetwork_by_address(
                address.network.to_string
              )
              raise Lib::ResourceNotFoundError, address.to_string unless vnetwork
            else
              vnetwork = Resource::VNetwork.new(address.network)
            end
            @node_config.vnetwork_add(vnetwork) 
          end

          viface.attach(vnetwork,address) unless daemon?
          @node_config.vnode_configure(vnode.name)

          ret = viface.to_hash
        end

        return ret

      rescue Lib::AlreadyExistingResourceError
        raise
      rescue Exception
        vnetwork.remove_vnode(vnode) if vnetwork
        raise
      end
      end

      def vroute_create(networksrc,networkdst,nodegw,vnodename=nil)
        ret = {}
        vnode = get_vnode(vnodename) if vnodename
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
          target = nil
          if param.is_a?(Resource::VNode)
            target = param.host.address.to_s
          elsif param.is_a?(String)
            begin
              target = Resolv.getaddress(param)
            rescue Resolv::ResolvError
              raise Lib::InvalidParameterError, param
            end
          end
          ret = Lib::NetTools.localaddr?(target) if target
        else
          ret = true
        end
        return ret
      end

      def get_vnode(name, raising = true)
        if daemon?
          ret = @daemon_resources.get_vnode(name)
        else
          ret = @node_config.get_vnode(name)
        end

        raise Lib::ResourceNotFoundError, name if raising and !ret

        return ret
      end

      def destroy(resource)
        if daemon?
          @daemon_resources.destroy(resource)
        end
        @node_config.destroy(resource)
      end

    end

  end
end
