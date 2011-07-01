require 'wrekavoc'
require 'thread'
require 'socket'
require 'ipaddress'
require 'json'

module Wrekavoc
  module Daemon

    class WrekaDaemon
      MODE_DAEMON=0
      MODE_NODE=1

      # >>> TODO: To be removed
      attr_reader :daemon_resources, :node_config

      def initialize(mode=MODE_NODE)
        @node_name = Socket::gethostname
        @mode = mode
        @threads = {}
        @threads['pnode_init'] = {}
        @threads['vnode_create'] = {}
        @threads['vnode_start'] = {}
        @threads['vnode_stop'] = {}

        @node_config = Node::ConfigManager.new

        if @mode == MODE_DAEMON
          @daemon_resources = Resource::VPlatform.new
        end
      end

      def pnode_init(target,properties={})
      begin
        pnode = nil

        nodemodeblock = Proc.new {
          pnode = @node_config.pnode
          Node::Admin.init_node()
          @node_config.vplatform.add_pnode(pnode)
          pnode.status = Resource::Status::RUNNING
        }
        if daemon?
          pnode = @daemon_resources.get_pnode_by_address(target)
          pnode = Resource::PNode.new(target) unless pnode

          @daemon_resources.add_pnode(pnode)

          block = Proc.new {
            if target?(target)
              @node_config.pnode = pnode
              nodemodeblock.call
            else
                Admin.pnode_run_server(pnode)
                sleep(1)
                cl = NetAPI::Client.new(target)
                cl.pnode_init(target)
            end
            pnode.status = Resource::Status::RUNNING
          }

          if properties['async']
            @threads['pnode_init'][pnode.address.to_s] = Thread.new {
              block.call
            }
          else
            block.call
          end
        else
          if target?(target)
            nodemodeblock.call
          end
        end

        return pnode
      rescue Lib::AlreadyExistingResourceError
        raise
      rescue Exception
        destroy(pnode) if pnode
        raise
      end
      end

      def pnode_wait(target)
        pnode = pnode_get(target)

        @threads['pnode_init'][pnode.address.to_s].join \
          if @threads['pnode_init'][pnode.address.to_s]
      end

      def pnode_quit(target)
        pnode = pnode_get(target)
        if daemon?
          @daemon_resources.vnodes.each_value do |vnode|
            if vnode.host == pnode
              vnode_remove(vnode.name)
            end
          end
          if target?(target)
            raise Lib::InvalidParameterError, target \
              if @daemon_resources.pnodes.size > 1
          else
            cl = NetAPI::Client.new(target)
            cl.pnode_quit(target)
          end
          @daemon_resources.remove_pnode(pnode)
        end

        if target?(target)
          #vnodes_remove()
          #vnetworks_remove()
          Node::Admin.quit_node()
          Thread.new do
            sleep(2)
            exit!
          end
        end

        return pnode
      end

      def pnodes_quit()
        ret = []
        if daemon?
          me = nil
          @daemon_resources.pnodes.each_value do |pnode|
            if target?(pnode.address.to_s)
              me = pnode.address.to_s
              next
            end
            ret << pnode_quit(pnode.address.to_s).to_hash
          end
          ret << pnode_quit(me).to_hash
        end
        return ret
      end

      def pnode_get(hostname, raising = true) 
        ret = nil
        begin
          address = Resolv.getaddress(hostname)
        rescue Resolv::ResolvError
          raise Lib::InvalidParameterError, hostname
        end

        if daemon?
          pnode = @daemon_resources.get_pnode_by_address(address)
        else
          pnode = @node_config.vplatform.get_pnode_by_address(address)
        end

        raise Lib::ResourceNotFoundError, hostname if raising and !pnode

        return pnode
      end

      def pnodes_get()
        ret = []
        if daemon?
          vplatform = @daemon_resources
        else
          @node_config.vplatform
        end

        vplatform.pnodes.each_value do |pnode|
          ret << pnode.to_hash
        end

        return ret
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
          raise Lib::UninitializedResourceError, pnode.address.to_s + @node_config.pnode.address.to_s \
            unless pnode.status == Resource::Status::RUNNING
        else
          hostname = properties['target']
          raise Lib::ResourceNotFoundError, (hostname ? hostname : 'Any')
        end
        raise Lib::MissingParameterError, "image" unless properties['image']

        #Create the resource
        vnode = Resource::VNode.new(pnode,name,properties['image'])

        nodemodeblock = Proc.new {
          vnode.status = Resource::Status::CONFIGURING
          @node_config.vnode_add(vnode)
          vnode.status = Resource::Status::READY
        }

        if daemon?
          @daemon_resources.add_vnode(vnode)

          block = Proc.new {
            if target?(pnode.address.to_s)
              nodemodeblock.call
            else
              vnode.status = Resource::Status::CONFIGURING
              cl = NetAPI::Client.new(pnode.address.to_s)
              cl.vnode_create(vnode.name,properties)
              vnode.status = Resource::Status::READY
            end
          }

          if properties['async']
            @threads['vnode_create'][vnode.name] = Thread.new {
              block.call
            }
          else
            block.call
          end
        else
          if target?(pnode.address.to_s)
            nodemodeblock.call
          end
        end

        return vnode

      rescue Lib::AlreadyExistingResourceError
        raise
      rescue Exception
        destroy(vnode) if vnode
        raise
      end

      end

      def vnode_remove(name)
        vnode = vnode_get(name)
        vnode.vifaces.each { |viface| viface_remove(name,viface.name) }

        if daemon?
          @daemon_resources.remove_vnode(vnode)
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            cl.vnode_remove(vnode.name)
          end
        end

        if target?(vnode)
          @node_config.vnode_remove(vnode)
        end

        return vnode
      end

      def vnode_wait(name)
        vnode = vnode_get(name)

        @threads['vnode_create'][vnode.name].join \
          if @threads['vnode_create'][vnode.name]
        @threads['vnode_start'][vnode.name].join \
          if @threads['vnode_start'][vnode.name]
        @threads['vnode_stop'][vnode.name].join \
          if @threads['vnode_stop'][vnode.name]
      end

      def vnode_get(name, raising = true)
        if daemon?
          vnode = @daemon_resources.get_vnode(name)
        else
          vnode = @node_config.get_vnode(name)
        end

        raise Lib::ResourceNotFoundError, name if raising and !vnode

        return vnode
      end

      def vnode_set_status(name,status,properties)
        vnode = nil
        raise Lib::InvalidParameterError, status \
          unless Resource::Status.valid?(status)
        if status.upcase == Resource::Status::RUNNING
          vnode = vnode_start(name,properties)
        elsif status.upcase == Resource::Status::READY
          vnode = vnode_stop(name,properties)
        else
          raise Lib::InvalidParameterError, status
        end

        return vnode
      end

      def vnode_start(name,properties = {})
        vnode = vnode_get(name)
        raise Lib::BusyResourceError, vnode.name \
          if vnode.status == Resource::Status::CONFIGURING
        raise Lib::UnitializedResourceError, vnode.name \
          if vnode.status == Resource::Status::INIT
        raise Lib::ResourceError, "#{vnode.name} already running" \
          if vnode.status == Resource::Status::RUNNING

        nodemodeblock = Proc.new {
          vnode.status = Resource::Status::CONFIGURING
          @node_config.vnode_start(vnode.name)
          vnode.status = Resource::Status::RUNNING
        }

        if daemon?
          block = Proc.new {
            if target?(vnode)
              nodemodeblock.call
            else
              vnode.status = Resource::Status::CONFIGURING
              cl = NetAPI::Client.new(vnode.host.address)
              cl.vnode_start(vnode.name)
              vnode.status = Resource::Status::RUNNING
            end
          }
          if properties['async']
            @threads['vnode_start'][vnode.name] = Thread.new {
              block.call
            }
          else
            block.call
          end
        else
          if target?(vnode)
            nodemodeblock.call
          end
        end

        return vnode
      end

      def vnode_stop(name, properties = {})
        vnode = vnode_get(name)
        raise Lib::BusyResourceError, vnode.name \
          if vnode.status == Resource::Status::CONFIGURING
        raise Lib::UnitializedResourceError, vnode.name \
          if vnode.status == Resource::Status::INIT

        nodemodeblock = Proc.new {
          vnode.status = Resource::Status::CONFIGURING
          @node_config.vnode_stop(vnode.name)
          vnode.status = Resource::Status::READY
        }

        if daemon?
          block = Proc.new {
            if target?(vnode)
              nodemodeblock.call
            else
              vnode.status = Resource::Status::CONFIGURING
              cl = NetAPI::Client.new(vnode.host.address)
              cl.vnode_stop(vnode.name)
              vnode.status = Resource::Status::READY
            end
          }
          if properties['async']
            @threads['vnode_stop'][vnode.name] = Thread.new {
              block.call
            }
          else
            block.call
          end
        else
          if target?(vnode)
            nodemodeblock.call
          end
        end

        return vnode
      end

      def vnodes_get()
        ret = []
        if daemon?
          vplatform = @daemon_resources
        else
          @node_config.vplatform
        end

        vplatform.vnodes.each_value do |vnode|
          ret << vnode.to_hash
        end

        return ret
      end

      def vnodes_remove()
        ret = []
        vnodes = nil
        if daemon?
          vnodes = @daemon_resources.vnodes
        else
          vnodes = @node_config.vplatform.vnodes
        end

        vnodes.each_value do |vnode|
          ret << vnode.to_hash
          vnode_remove(vnode.name)
        end

        return ret
      end

      def viface_create(vnodename,vifacename)
      begin
        vnode = vnode_get(vnodename)

        viface = Resource::VIface.new(vifacename,vnode)
        vnode.add_viface(viface)

        if daemon?
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            cl.viface_create(vnode.name,viface.name)
          end
        end

        if target?(vnode)
          @node_config.viface_add(viface)
          #@node_config.vnode_configure(vnode.name)
        end

        return viface

      rescue Lib::AlreadyExistingResourceError
        raise
      rescue Exception
        vnode.remove_viface(viface) if vnode and viface
        raise
      end
      end

      def viface_remove(vnodename,vifacename)
        vnode = vnode_get(vnodename)
        viface = viface_get(vnodename,vifacename)
        viface.detach()
        vnode.remove_viface(viface)

        if daemon?
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            cl.viface_remove(vnode.name,viface.name)
          end
        end

        if target?(vnode)
          @node_config.viface_remove(viface)
          #@node_config.vnode_configure(vnode.name)
        end

        return viface
      end

      def viface_get(vnodename,vifacename,raising = true)
        vnode = vnode_get(vnodename,raising)
        viface = vnode.get_viface_by_name(vifacename)

        raise Lib::ResourceNotFoundError, vifacename if raising and !viface

        return viface
      end

      def vnode_set_mode(name,mode)
        # >>> TODO: Ability to unset gateway mode
        vnode = vnode_get(name)
        if mode.upcase == Resource::VNode::MODE_GATEWAY
          if daemon?
            unless target?(vnode)
              cl = NetAPI::Client.new(vnode.host.address)
              cl.vnode_gateway(vnode.name)
            end
          end

          if target?(vnode)
            vnode.gateway = true
            #@node_config.vnode_configure(vnode.name)
          end
        elsif mode.upcase == Resource::VNode::MODE_NORMAL
        else
          raise Lib::InvalidParameterError, mode
        end

        return vnode
      end

      def vnode_info_rootfs(name)
        # >>> TODO: Check if VNode exists
        vnode = vnode_get(name)

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

      def vnode_execute(vnodename,command)
        ret = {}
        if daemon?
          # >>> TODO: check if vnode exists
          vnode = vnode_get(vnodename)
          raise Lib::UnitializedResourceError, vnode.name \
            unless vnode.status == Resource::Status::RUNNING

          raise unless vnode

          ret['command'] = command
          ret['result'] = Daemon::Admin.vnode_run(vnode,command)
        end

        return ret
      end

      def vnetwork_create(name,address)
      begin
        vnetwork = Resource::VNetwork.new(address,name)
        if daemon?
          @daemon_resources.add_vnetwork(vnetwork)
          #Add a virtual interface connected on the network
          Lib::NetTools.set_new_nic(Daemon::Admin.get_vnetwork_addr(vnetwork))
        end
        @node_config.vnetwork_add(vnetwork)

        return vnetwork

      rescue Lib::AlreadyExistingResourceError
        raise
      rescue Exception
        destroy(vnetwork) if vnetwork
        raise
      end
      end

      def vnetwork_remove(name)
        vnetwork = vnetwork_get(name)

        if daemon?
          hosts = []
          vnetwork.vnodes.each_pair do |vnode,viface|
            hosts << vnode.host.address.to_s \
              unless hosts.include?(vnode.host.address.to_s)
            viface_detach(vnode.name,viface.name)
          end

          @daemon_resources.remove_vnetwork(vnetwork)
          hosts.each do |pnodeaddr|
            next if target?(pnodeaddr)
            cl = NetAPI::Client.new(pnodeaddr)
            cl.vnetwork_remove(vnetwork.name)
          end
        end

        @node_config.vnetwork_remove(vnetwork)

        return vnetwork
      end

      def vnetworks_remove()
        ret = []
        vnetworks = nil
        if daemon?
          vnetworks = @daemon_resources.vnetworks
        else
          vnetworks = @node_config.vplatform.vnetworks
        end

        vnetworks.each_value do |vnetwork|
          ret << vnetwork.to_hash
          vnetwork_remove(vnetwork.name)
        end

        return ret
      end

      def vnetwork_get(name,raising = true)
        if daemon?
          vnetwork = @daemon_resources.get_vnetwork_by_name(name)
        else
          vnetwork = @node_config.vplatform.get_vnetwork_by_name(name)
        end

        raise Lib::ResourceNotFoundError, name if raising and !vnetwork

        return vnetwork
      end

      def vnetworks_get()
        ret = []
        if daemon?
          vplatform = @daemon_resources
        else
          @node_config.vplatform
        end

        vplatform.vnetworks.each_value do |vnetwork|
          ret << vnetwork.to_hash
        end

        return ret
     end

      def viface_attach(vnodename,vifacename,properties)
      begin
        vnode = vnode_get(vnodename)
        viface = viface_get(vnodename,vifacename)
        viface_detach(vnodename,vifacename) if viface.attached?
        limits = nil

        raise Lib::ResourceNotFoundError, vifacename unless viface
        #raise Lib::AlreadyExistingResourceError, 'attach' if viface.attached?
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

          raise Lib::ResourceNotFoundError, "network:#{prop}" unless vnetwork

          if properties['address']
            vnetwork.add_vnode(vnode,viface,address)
          else
            vnetwork.add_vnode(vnode,viface)
          end

          properties['address'] = viface.address.to_string

          unless target?(vnode)
            properties['vnetwork'] = vnetwork.name
            cl = NetAPI::Client.new(vnode.host.address)
            cl.viface_attach(vnode.name,viface.name,properties)
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
          vnetwork = @node_config.vplatform.get_vnetwork_by_name(properties['vnetwork']) unless vnetwork

          #Networks are not systematically created on every pnode
          unless vnetwork
            if daemon?
              vnetwork = @daemon_resources.get_vnetwork_by_address(
                address.network.to_string
              )
              raise Lib::ResourceNotFoundError, address.to_string unless vnetwork
              @node_config.vnetwork_add(vnetwork)
            else
              raise MissingParameterError, 'vnetwork' unless properties['vnetwork']
              vnetwork = vnetwork_create(properties['vnetwork'],
                address.network.to_string
              )
            end
          end

          viface.attach(vnetwork,address) unless daemon?
          #@node_config.vnode_configure(vnode.name)
        end

        #Set the limitations if there is some
        if properties['limitation']
          limits = Limitation::Network::Manager.parse_limitations(
            vnode,viface,properties['limitation']
          ) 
          viface.add_limitation(limits)
        end

        if target?(vnode)
          #@node_config.vnode_configure(vnode.name) if limits
        end

        return viface

      rescue Lib::AlreadyExistingResourceError
        raise
      rescue Exception
        vnetwork.remove_vnode(vnode) if vnetwork
        viface.remove_limitation(properties['limitation']) \
          if properties['limitation']
        raise
      end
      end

      def viface_detach(vnodename,vifacename)
        vnode = vnode_get(vnodename)
        viface = viface_get(vnodename,vifacename)
        viface.detach()
        if daemon?
          unless target?(vnode)
            cl = NetAPI::Client.new(vnode.host.address)
            cl.viface_detach(vnode.name,viface.name)
          end
        end

        if target?(vnode)
          @node_config.viface_detach(viface)
          #@node_config.vnode_configure(vnode.name)
        end

        return viface
      end

      def vroute_create(networksrc,networkdst,nodegw,vnodename=nil)
      begin
        vnode = nil
        vnode = vnode_get(vnodename) if vnodename
        srcnet = vnetwork_get(networksrc)
        destnet = vnetwork_get(networkdst,false)
        if daemon? and !target?(vnode)
          gw = vnode_get(nodegw)
          gwaddr = gw.get_viface_by_network(srcnet)
          gwaddr = gwaddr.address if gwaddr
        else
          begin
            gw = IPAddress.parse(nodegw)
          rescue ArgumentError
            raise InvalidParameterError, nodegw
          end
          gwaddr = gw
          destnet = @node_config.vplatform.get_vnetwork_by_address(networkdst) \
            unless destnet
          destnet = Resource::VNetwork.new(networkdst) unless destnet
        end

        raise Lib::ResourceNotFoundError, networksrc unless srcnet
        raise Lib::ResourceNotFoundError, networkdst unless destnet
        raise Lib::ResourceNotFoundError, nodegw unless gw
        raise Lib::InvalidParameterError, nodegw unless gwaddr

        vroute = srcnet.get_vroute(destnet)
        unless vroute
          vroute = Resource::VRoute.new(srcnet,destnet,gwaddr)
          srcnet.add_vroute(vroute)
        end

        if daemon? 
          unless target?(vnode)
            raise Lib::InvalidParameterError, "#{gw.name} #{srcnet} " \
              unless gw.connected_to?(srcnet)
            vnode_set_mode(gw.name,Resource::VNode::MODE_GATEWAY) \
              unless gw.gateway
          end

          unless vnode
            srcnet.vnodes.each_key do |vnode|
              if target?(vnode)
                vroute_create(srcnet.name, 
                  destnet.address.to_string,gwaddr.to_s,vnode.name)
              else
                cl = NetAPI::Client.new(vnode.host.address)
                cl.vroute_create(srcnet.name, 
                  destnet.address.to_string,gwaddr.to_s, vnode.name)
              end
            end
          end
        end

        if vnode and target?(vnode)
          #@node_config.vnode_configure(vnode.name)
        end

        return vroute
      rescue Lib::AlreadyExistingResourceError
        raise
      rescue Exception
        destroy(vroute) if srcnet
        raise
      end
      end

      def vroute_complete()
        ret = []

        if daemon?
          # >>> TODO: Use vnetworks_get
          @daemon_resources.vnetworks.each_value do |srcnet|
            @daemon_resources.vnetworks.each_value do |destnet|
              next if srcnet == destnet
              gw = srcnet.perform_vroute(destnet)
              ret << vroute_create(srcnet.name,destnet.name,gw.name) if gw
            end
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

      def destroy(resource)
        if daemon?
          @daemon_resources.destroy(resource)
        end
        @node_config.destroy(resource)
      end

    end

  end
end
