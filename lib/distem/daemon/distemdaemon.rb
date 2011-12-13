require 'distem'
require 'thread'
require 'socket'
require 'ipaddress'
require 'json'
require 'pp'

module Distem
  module Daemon

    # The main daemon class. Both used by the coordinator daemon to contact each physical nodes and create virtual resources in them and manage every virtual resources and by the physical nodes daemon to set up physical resources to fit to virtual resources specifications. See REST API documentation for the methods specifications.
    class DistemDaemon
      # The dameon is in coordinator mode
      MODE_DAEMON=0
      # The daemon is in normal mode
      MODE_NODE=1

      # >>> TODO: Remove attr_readers

      # The VPlatform object that describes each resources in the experimental platform
      attr_reader :daemon_resources
      # The NodeConfig object that allows to apply virtual resources specifications on physical nodes
      attr_reader  :node_config

      @@locks = {
        :vnetsync => {},
      }

      @@threads = {
        :pnode_init => {},
        :vnode_start => {},
        :vnode_stop => {},
      }

      # Create a new Daemon
      # ==== Attribute
      # * +mode+ The mode the daemon should be executed in (0 for Coordinator, 1 for Normal)
      #
      def initialize(mode=MODE_NODE)
        #Thread::abort_on_exception = true
        @node_name = Socket::gethostname
        @mode = mode


        @node_config = Node::ConfigManager.new

        if @mode == MODE_DAEMON
          @daemon_resources = Resource::VPlatform.new
        end
      end


      # Initialise a physical machine (launching daemon, creating cgroups, ...)
      # This step have to be performed to be able to create virtual nodes on a machine
      # ==== Attributes
      # * +target+ the name/address of the physical machine
      # * +properties+ async,max_vifaces,cpu_algorithm
      # ==== Returns
      # Resource::PNode object
      # ==== Exceptions
      #
      def pnode_create(target,desc={},async=false)
        begin
          async = parse_bool(async)
          pnode = nil

          nodemodeblock = Proc.new {
            pnode = @node_config.pnode
            Node::Admin.init_node(pnode,desc)

            @node_config.vplatform.add_pnode(pnode)
            pnode.status = Resource::Status::RUNNING
          }

          if daemon?
            if target?(target)
              pnode = @node_config.pnode
            else
              pnode = @daemon_resources.get_pnode_by_address(target)
              pnode = Resource::PNode.new(target) unless pnode
            end

            @daemon_resources.add_pnode(pnode)

            block = Proc.new {
              unless target?(target)
                Admin.pnode_run_server(pnode)
                cl = NetAPI::Client.new(target)
                ret = cl.pnode_init(nil,desc,async)
                updateobj_pnode(pnode,ret)
              end
              pnode.status = Resource::Status::RUNNING
            }

            if async
              thr = @@threads[:pnode_init][pnode.address.to_s] = Thread.new {
                block.call
              }
              #thr.abort_on_exception = true
            else
              block.call
            end
          end

          if target?(target)
            nodemodeblock.call
          end

          pnode_update(pnode.address.to_s,desc)

          return pnode
        rescue Lib::AlreadyExistingResourceError
          raise
        rescue Exception
          destroy(pnode) if pnode
          raise
        end
      end

      # Update PNode properties
      def pnode_update(target,desc)
        pnode = pnode_get(target)

        if desc['algorithms']
          if desc['algorithms']['cpu']
            algo = desc['algorithms']['cpu'].upcase
            raise InvalidParameterError "algorithms/cpu" unless \
              [Algorithm::CPU::GOV.upcase,
              Algorithm::CPU::HOGS.upcase].include?(algo)
            pnode.algorithms[:cpu] = algo
          end
        end
      end

      # Wait for a PNode to be ready
      def pnode_wait(target)
        pnode = pnode_get(target)

        @@threads[:pnode_init][pnode.address.to_s].join if \
          @@threads[:pnode_init][pnode.address.to_s]
      end

      # Quit distem on a physical machine (remove everything that was created)
      # ==== Returns
      # Resource::PNode object
      # ==== Exceptions
      #
      def pnode_quit(target)
        pnode = pnode_get(target,false)
        pnode.status = Resource::Status::CONFIGURING
        if daemon? and pnode
          @daemon_resources.vnodes.each_value do |vnode|
            if vnode.host == pnode
              vnode_stop(vnode.name)
            end
          end

          if target?(target)
            raise Lib::InvalidParameterError, target if \
              @daemon_resources.pnodes.size > 1
          else
            cl = NetAPI::Client.new(target)
            cl.pnode_quit(target)
          end
          @daemon_resources.remove_pnode(pnode)
        end

        if target?(target)
          vnodes_remove()
          vnetworks_remove()

          Node::Admin.quit_node()
          Thread.new do
            sleep(2)
            exit!
          end
        end
        pnode.status = Resource::Status::READY
        return pnode
      end

      # Quit distem on all the physical machines (remove everything that was created)
      # ==== Returns
      # Array of Resource::PNode objects
      # ==== Exceptions
      #
      def pnodes_quit()
        if daemon?
          me = nil
          ret = @daemon_resources.pnodes.dup
          @daemon_resources.pnodes.each_value do |pnode|
            if target?(pnode.address.to_s)
              me = pnode.address.to_s
              next
            end
            pnode_quit(pnode.address.to_s)
          end
          pnode_quit(me)
        end
        return ret
      end

      # Get the description of a virtual node
      #
      # ==== Attributes
      #
      def pnode_get(hostname, raising = true) 
        ret = nil

        if hostname and Lib::NetTools.localaddr?(hostname)
          pnode = @node_config.pnode
        else
          hostname = '' unless hostname
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
        end

        raise Lib::ResourceNotFoundError, hostname if raising and !pnode

        return pnode
      end

      # Get the list of the the currently created physical nodes
      # ==== Returns
      # Array of Resource::PNode objects
      # ==== Exceptions
      #
      def pnodes_get()
        vplatform = nil
        if daemon?
          vplatform = @daemon_resources
        else
          vplatform = @node_config.vplatform
        end

        return vplatform.pnodes
      end

      # Get the description of the cpu of a physical node
      def pcpu_get(hostname, raising = true) 
        pnode = pnode_get(hostname)

        return pnode.cpu
      end

      # Get the description of the memory of a physical node
      def pmemory_get(hostname, raising = true) 
        pnode = pnode_get(hostname)

        return pnode.memory
      end

      # Create a virtual node using a compressed file system image.
      #
      # ==== Attributes
      # * +name+ the -unique- name of the virtual node to create (it will be used in a lot of methods)
      # * +properties+ target,image,async,fs_shared,ssh_key
      # ==== Returns
      # Resource::VNode object
      # ==== Exceptions
      #
      def vnode_create(name,desc,ssh_key={},async=false)
        begin
          async = parse_bool(async)
          if name
            name = name.gsub(' ','_')
          else
            raise Lib::ArgumentMissingError "name"
          end

          downkeys(desc)

          vnode = Resource::VNode.new(name,ssh_key)

          if daemon?
            @daemon_resources.add_vnode(vnode)
          else
            @node_config.vnode_add(vnode)
          end

          vnode_update(vnode.name,desc,async)

          return vnode

        rescue Lib::AlreadyExistingResourceError
          raise
        rescue Exception
          destroy(vnode) if vnode
          raise
        end

      end

      # Update the vnode resource
      def vnode_update(name,desc,async=false)
        async = parse_bool(async)
        vnode = vnode_get(name)

        downkeys(desc)

        vnode_attach(vnode.name,desc['host']) if desc['host']

        vfilesystem_create(vnode.name,desc['vfilesystem']) if desc['vfilesystem']

        if desc['vcpu']
          if vnode.vcpu
            vcpu_update(vnode.name,desc['vcpu'])
          else
            vcpu_create(vnode.name,desc['vcpu'])
          end
        end

        if desc['vifaces']
          desc['vifaces'].each do |ifdesc|
            if vnode.get_viface_by_name(ifdesc['name'])
              viface_update(vnode.name,ifdesc['name'],ifdesc)
            else
              viface_create(vnode.name,ifdesc['name'],ifdesc)
            end
          end
        end

        vnode_mode_update(vnode.name,desc['mode']) if desc['mode']

        vnode_status_update(vnode.name,desc['status'],async) if desc['status']

        return vnode
      end

      # Remove the virtual node ("Cascade" removing -> remove all the vroutes it apears as gateway)
      # ==== Returns
      # Resource::VNode object
      # ==== Exceptions
      #
      def vnode_remove(name)
        vnode = vnode_get(name)

        raise Lib::BusyResourceError, "#{vnode.name}/running" if \
          vnode.status == Resource::Status::RUNNING

        ret = vnode.dup

        vnode.vifaces.each { |viface| viface_remove(name,viface.name) }
        vnode.remove_vcpu()

        if daemon?
          @daemon_resources.remove_vnode(vnode)
          if !target?(vnode) and vnode.host and (pnode.status == Resource::Status::RUNNING)
            cl = NetAPI::Client.new(vnode.host.address)
            cl.vnode_remove(vnode.name)
          end
        end

        if target?(vnode)
          @node_config.vnode_remove(vnode)
        end

        return ret
      end

      def vnode_attach(name,host)
        vnode = vnode_get(name)
        if daemon?
          pnode = @daemon_resources.get_pnode_by_address(host)
        else
          pnode = @node_config.pnode
        end

        if pnode
          raise Lib::UninitializedResourceError, pnode.address.to_s unless \
            pnode.status == Resource::Status::RUNNING
        else
          raise Lib::ResourceNotFoundError host if host
        end

        if vnode.host and vnode.status == Resource::Status::RUNNING
          raise Lib::AlreadyExistingResourceError, 'host'
        else
          vnode.host = pnode
        end

        return vnode
      end

      def vnode_wait(name)
        vnode = vnode_get(name)

        @@threads[:vnode_start][vnode.name].join if @@threads[:vnode_start][vnode.name]
        @@threads[:vnode_stop][vnode.name].join if @@threads[:vnode_stop][vnode.name]
      end

      # Get the description of a virtual node
      # ==== Returns
      # Resource::VNode object
      # ==== Exceptions
      #
      def vnode_get(name, raising = true)
        name = name.gsub(' ','_')
        if daemon?
          vnode = @daemon_resources.get_vnode(name)
        else
          vnode = @node_config.get_vnode(name)
        end

        raise Lib::ResourceNotFoundError, name if raising and !vnode

        return vnode
      end

      # Change the status of the -previously created- virtual node.
      #
      # ==== Attributes
      # * +status+ the status to set: "Running" or "Ready"
      # * +properties+ async
      # ==== Returns
      # Resource::VNode object
      # ==== Exceptions
      #
      def vnode_status_update(name,status,async=false)
        async = parse_bool(async)
        vnode = nil
        raise Lib::InvalidParameterError, status unless \
          Resource::Status.valid?(status)
        if status.upcase == Resource::Status::RUNNING
          vnode = vnode_start(name,async)
        elsif status.upcase == Resource::Status::READY
          vnode = vnode_stop(name,async)
        else
          raise Lib::InvalidParameterError, status
        end

        return vnode
      end

      # Same as vnode_set_status(name,Resource::Status::RUNNING,properties)
      def vnode_start(name,async=false)
        async = parse_bool(async)
        vnode = vnode_get(name)

        raise Lib::BusyResourceError, vnode.name if \
          vnode.status == Resource::Status::CONFIGURING

        raise Lib::ResourceError, "#{vnode.name} already running" if \
          vnode.status == Resource::Status::RUNNING

        nodemodeblock = Proc.new {
          vnode.status = Resource::Status::CONFIGURING
          vnode.host = @node_config.pnode unless vnode.host
          vnode.vcpu.attach if vnode.vcpu and !vnode.vcpu.attached?
          @node_config.vnode_start(vnode)
          vnode.status = Resource::Status::RUNNING
        }

        if daemon?
          vnode.status = Resource::Status::CONFIGURING

          vnode.host = @daemon_resources.get_pnode_available(vnode) unless \
            vnode.host
          vnode.vcpu.attach if vnode.vcpu and !vnode.vcpu.attached?


          block = Proc.new {
            if target?(vnode)
              nodemodeblock.call
            else
              cl = NetAPI::Client.new(vnode.host.address.to_s)

              # Create VNetworks on remote PNode
              vnode.get_vnetworks.each do |vnet|
                vnetwork_sync(vnet,vnode.host)
              end

              desc = TopologyStore::HashWriter.new.visit(vnode)
              # we want the node to be runned
              desc['status'] = Resource::Status::RUNNING

              ret = cl.vnode_create(vnode.name,desc)

              #ret = cl.vnode_start(vnode.name,properties)

              updateobj_vnode(vnode,ret)

              vnode.status = Resource::Status::RUNNING
            end
          }

          if async
            thr = @@threads[:vnode_start][vnode.name] = Thread.new {
              block.call
            }
            thr.abort_on_exception = true
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

      # Same as vnode_set_status(name,Resource::Status::READY,properties)
      def vnode_stop(name, async=false)
        async = parse_bool(async)
        vnode = vnode_get(name)
        raise Lib::BusyResourceError, vnode.name if \
          vnode.status == Resource::Status::CONFIGURING
        raise Lib::UninitializedResourceError, vnode.name if \
          vnode.status == Resource::Status::INIT

        nodemodeblock = Proc.new {
          vnode.status = Resource::Status::CONFIGURING
          @node_config.vnode_stop(vnode)
          vnode.status = Resource::Status::READY
        }

        if daemon?
          block = Proc.new {
            if target?(vnode)
              nodemodeblock.call
            else
              vnode.status = Resource::Status::CONFIGURING
              Distem.client(vnode.host.address) do |cl|
                cl.vnode_stop(vnode.name)
                cl.vnode_remove(vnode.name)
              end
              vnode.status = Resource::Status::READY
            end
            vnode.vcpu.detach if vnode.vcpu
            vnode.host = nil
          }

          if async
            thr = @@threads[:vnode_stop][vnode.name] = Thread.new {
              block.call
            }
            thr.abort_on_exception = true
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


      # Change the mode of a virtual node (normal or gateway)
      # ==== Attributes
      # * +mode+ "Normal" or "Gateway"
      # ==== Returns
      # Resource::VNode object
      # ==== Exceptions
      #
      def vnode_mode_update(name,mode)
        vnode = vnode_get(name)

        case mode.upcase
        when Resource::VNode::MODE_GATEWAY.upcase
          vnode.gateway = true
        when Resource::VNode::MODE_NORMAL.upcase
          vnode.gateway = false
        else
          raise Lib::InvalidParameterError, "mode:#{mode}"
        end

        return vnode
      end

      # Get the list of the the currently created virtual nodes
      # ==== Returns
      # Array of Resource::PNode objects
      # ==== Exceptions
      #
      def vnodes_get()
        vnodes = nil
        if daemon?
          vnodes = @daemon_resources.vnodes
        else
          vnodes = @node_config.vplatform.vnodes
        end

        return vnodes
      end

      # Remove every virtual nodes
      # ==== Returns
      # Array of Resource::PNode objects
      # ==== Exceptions
      #
      def vnodes_remove()
        vnodes = nil
        if daemon?
          vnodes = @daemon_resources.vnodes
        else
          vnodes = @node_config.vplatform.vnodes
        end

        vnodes.each_value { |vnode| vnode_remove(vnode.name) }

        return vnodes
      end

      # Create a new virtual interface on the targeted virtual node (without attaching it to any network -> no ip address)
      # ==== Attributes
      # * +name+ the name of the virtual interface (need to be unique on this virtual node)
      # ==== Returns
      # Resource::VIface object
      # ==== Exceptions
      #
      def viface_create(vnodename,vifacename,desc)
        begin
          vifacename = vifacename.gsub(' ','_')
          vnode = vnode_get(vnodename)

          viface = Resource::VIface.new(vifacename,vnode)

          if target?(vnode)
            raise Lib::DistemError, "Maximum ifaces number of #{Node::Admin.vifaces_max} reached" if viface.id >= Node::Admin.vifaces_max
            Lib::Shell.run("ip link set dev ifb#{viface.id} up")
          end

          vnode.add_viface(viface)

          downkeys(desc)

          viface_update(vnode.name,viface.name,desc)

          return viface

        rescue Lib::AlreadyExistingResourceError
          raise
        rescue Exception
          vnode.remove_viface(viface) if vnode and viface
          raise
        end
      end

      # Remove the virtual interface
      # ==== Returns
      # Resource::VIface object
      # ==== Exceptions
      #
      def viface_remove(vnodename,vifacename)
        vnode = vnode_get(vnodename)
        viface = viface_get(vnodename,vifacename)
        viface_detach(vnode.name,viface.name)
        vnode.remove_viface(viface)

        return viface
      end

      def viface_update(vnodename,vifacename,desc)
        ret = nil
        downkeys(desc)
        if !desc or desc.empty?
          ret = viface_detach(vnodename,vifacename)
        else
          if (desc.keys - ['input'] - ['output']).size == 0
            #only vtraffic change
            ret = vtraffic_update(vnodename,vifacename,desc)
          else
            ret = viface_attach(vnodename,vifacename,desc)
          end
        end
        return ret
      end

      # Connect a virtual node on a virtual network specifying which of it's virtual interface to use
      # The IP address is auto assigned to the virtual interface
      # Dettach the virtual interface if properties is empty
      # You can change the traffic specification on the fly, only specifying a vtraffic property
      # ==== Attributes
      # * +vnodename+ The VNode name (String)
      # * +vifacename+ The VIface name (String)
      # * +properties+ the address or the vnetwork to connect the virtual interface with (JSON, 'address' or 'vnetwork'), the traffic the interface will have to emulate (not mandatory, JSON, 'vtraffic', INPUT/OUTPUT)
      # == Usage
      # properties['vtraffic'] sample: { "OUTPUT" : { "bandwidth" : {"rate" : "20mbps"}, "latency" : {"delay" : "5ms"} } }
      # ==== Returns
      # Resource::VIface object
      # ==== Exceptions
      #
      def viface_attach(vnodename,vifacename,desc)
        begin
          vnode = vnode_get(vnodename)
          viface = viface_get(vnodename,vifacename)

          downkeys(desc)

          desc['vnetwork'] = desc['vnetwork'].gsub(' ','_') if desc['vnetwork']

          if daemon?
            raise Lib::MissingParameterError, "address|vnetwork" if \
              ((!desc['address'] or desc['address'].empty?) \
               and (!desc['vnetwork'] or desc['vnetwork'].empty?))

            vplatform = @daemon_resources
          else
            raise Lib::MissingParameterError, "address&vnetwork" if \
              ((!desc['address'] or desc['address'].empty?) \
               or (!desc['vnetwork'] or desc['vnetwork'].empty?))
            vplatform = @node_config.vplatform
          end

          if desc['address'] and !desc['address'].empty?
            begin
              address = IPAddress.parse(desc['address'])
            rescue ArgumentError
              raise Lib::InvalidParameterError, desc['address']
            end
            prop = desc['address']
            vnetwork = vplatform.get_vnetwork_by_address(prop)
          end

          if desc['vnetwork'] and !desc['vnetwork'].empty?
            prop = desc['vnetwork']
            vnetwork = vplatform.get_vnetwork_by_name(prop)
          end

          raise Lib::ResourceNotFoundError, "vnetwork:#{prop}" unless vnetwork

          if desc['address']
            vnetwork.add_vnode(vnode,viface,address)
          else
            vnetwork.add_vnode(vnode,viface)
          end

          desc.delete('address')
          desc.delete('vnetwork')
          vtraffic_update(vnode.name,viface.name,desc) unless desc.empty?

          return viface
        rescue Lib::AlreadyExistingResourceError
          raise
        rescue Exception
          vnetwork.remove_vnode(vnode) if vnetwork
          raise
        end
      end

      # Disconnect a virtual network interface from every networks it's connected to
      # ==== Attributes
      # * +vnodename+ The VNode name (String)
      # * +vifacename+ The VIface name (String)
      # ==== Returns
      # Resource::PNode object
      # ==== Exceptions
      #
      def viface_detach(vnodename,vifacename)
        vnode = vnode_get(vnodename)
        viface = viface_get(vnodename,vifacename)
        viface.detach()

        return viface
      end

      # Get the description of a virtual network interface
      # ==== Returns
      # Resource::VIface object
      # ==== Exceptions
      #
      def viface_get(vnodename,vifacename,raising = true)
        vifacename = vifacename.gsub(' ','_')
        vnode = vnode_get(vnodename,raising)
        viface = vnode.get_viface_by_name(vifacename)

        raise Lib::ResourceNotFoundError, vifacename if raising and !viface

        return viface
      end

      # Configure the virtual traffic on a virtual network interface, replacing previous values
      # ==== Attributes
      # * +vnodename+ The VNode name (String)
      # * +vifacename+ The VIface name (String)
      # * +desc+ Hash that represents the VTraffic description (see Lib::Validator)
      # ==== Returns
      # Resource::VIface object
      # ==== Exceptions
      #
      def vtraffic_update(vnodename,vifacename,desc)
        vnode = vnode_get(vnodename)
        viface = viface_get(vnodename,vifacename)

        downkeys(desc)

          # Direction is switched because of the lxc-veth structure that cause the input and the output of the network interface to be switched inside of the container
        voutput_update(vnode.name,viface.name,desc['output']) if desc['output']
        vinput_update(vnode.name,viface.name,desc['input']) if desc['input']

        return viface
      end

      def vinput_get(vnodename,vifacename, raising = true)
        vnode = vnode_get(vnodename)
        viface = viface_get(vnodename,vifacename)

        raise Lib::UninitializedResourceError, 'input' if raising and !viface.vinput

        return viface.vinput
      end

      def voutput_update(vnodename,vifacename,desc)
        vnode = vnode_get(vnodename)
        viface = viface_get(vnodename,vifacename)

        downkeys(desc)

        if desc and !desc.empty?
          viface.vinput = Resource::VIface::VTraffic.new(viface,
            Resource::VIface::VTraffic::Direction::INPUT,desc)
        else
          viface.vinput = nil
        end

        if vnode.status == Resource::Status::RUNNING
          vnode.status = Resource::Status::CONFIGURING
          if target?(vnode)
              @node_config.vnode_reconfigure(vnode)
          elsif daemon?
            cl = NetAPI::Client.new(vnode.host.address)
            cl.vinput_update(vnode.name,viface.name,desc)
          end
          vnode.status = Resource::Status::RUNNING
        end

        return viface.vinput
      end

      def voutput_get(vnodename,vifacename, raising = true)
        vnode = vnode_get(vnodename)
        viface = viface_get(vnodename,vifacename)

        raise Lib::UninitializedResourceError, 'voutput' if raising and !viface.voutput

        return viface.voutput
      end

      def vinput_update(vnodename,vifacename,desc)
        vnode = vnode_get(vnodename)
        viface = viface_get(vnodename,vifacename)

        downkeys(desc)

        if desc and !desc.empty?
          viface.voutput = Resource::VIface::VTraffic.new(viface,
            Resource::VIface::VTraffic::Direction::OUTPUT,desc)
        else
          viface.voutput = nil
        end

        if vnode.status == Resource::Status::RUNNING
          vnode.status = Resource::Status::CONFIGURING
          if target?(vnode)
              @node_config.vnode_reconfigure(vnode)
          elsif daemon?
            cl = NetAPI::Client.new(vnode.host.address)
            cl.voutput_update(vnode.name,viface.name,desc)
          end
          vnode.status = Resource::Status::RUNNING
        end

        return viface.voutput
      end

      # Create a new virtual cpu on the targeted virtual node.
      # By default all the virtual nodes on a same physical one are sharing available CPU resources, using this method you can allocate some cores to a virtual node and apply some limitations on them
      #
      # ==== Attributes
      # * +corenb+ the number of cores to allocate (need to have enough free ones on the physical node)
      # * +frequency+ (optional) the frequency each node have to be set (need to be lesser or equal than the physical core frequency). If the frequency is included in ]0,1] it'll be interpreted as a percentage of the physical core frequency, otherwise the frequency will be set to the specified number
      # ==== Returns
      # Resource::VCPU object
      # ==== Exceptions
      #
      def vcpu_create(vnodename,desc)
        begin
          vnode = vnode_get(vnodename)

          downkeys(desc)

          corenb = nil
          freq = nil

          if desc['vcores']
            raise Lib::InvalidParameterError, 'vcores' unless desc['vcores'].is_a?(Array)
            corenb = desc['vcores'].size
            freq = desc['vcores'][0]['frequency'].split[0].to_f || 1.0
          else
            corenb = desc['corenb'].to_i || 1
            freq = desc['frequency'].to_f || 1.0
          end

          freq = freq * 1000 if freq > 1

          vnode.add_vcpu(corenb,freq)

          vnode.vcpu.attach if vnode.host

          if vnode.status == Resource::Status::RUNNING
            vnode.status = Resource::Status::CONFIGURING
            if target?(vnode)
              @node_config.vnode_reconfigure(vnode)
            elsif daemon?
              cl = NetAPI::Client.new(vnode.host.address)
              cl.cpu_update(vnode.name,desc)
            end
            vnode.status = Resource::Status::RUNNING
          end

          return vnode.vcpu

        rescue Lib::AlreadyExistingResourceError
          raise
        rescue Exception
          vnode.remove_vcpu() if vnode
          raise
        end
      end

      def vcpu_get(vnodename)
        vnode = vnode_get(vnodename)

        raise Lib::UninitializedResourceError, 'vcpu' unless vnode.vcpu

        return vnode.vcpu
      end

      def vcpu_update(vnodename,desc)
        begin
          vnode = vnode_get(vnodename)
          vcpu = vcpu_get(vnode.name)

          downkeys(desc)

          if desc['vcores']
            raise Lib::InvalidParameterError, 'vcores' unless desc['vcores'].is_a?(Array)
            freq = desc['vcores'][0]['frequency'].split(0).to_f || 1.0
          else
            freq = desc['frequency'].to_f || 1.0
          end

          freq = frequency * 1000 if frequency > 1

          vcpu.update_vcores(freq)

          if vnode.status == Resource::Status::RUNNING
            vnode.status = Resource::Status::CONFIGURING
            if target?(vnode)
              @node_config.vnode_reconfigure(vnode)
            elsif daemon?
              cl = NetAPI::Client.new(vnode.host.address)
              cl.cpu_update(vnode.name,desc)
            end
            vnode.status = Resource::Status::RUNNING
          end

          return vnode.vcpu
        rescue Lib::AlreadyExistingResourceError
          raise
        rescue Exception
          vnode.remove_vcpu() if vnode
          raise
        end
      end

      def vcpu_remove(vnodename)
        vnode = vnode_get(vnodename)

        raise Lib::UninitializedResourceError, 'vcpu' unless vnode.vcpu

        vcpu = vnode.vcpu
        vnode.remove_vcpu()

        return vcpu
      end


      def vfilesystem_create(vnodename,desc)
        vnode = vnode_get(vnodename)

        raise Lib::AlreadyExistingResourceError, 'filesystem' if vnode.filesystem

        raise Lib::MissingParameterError, "filesystem/image" unless \
          desc['image']

        desc['shared'] = parse_bool(desc['shared'])

        vnode.filesystem = Resource::FileSystem.new(vnode,desc['image'],desc['shared'])

        return vnode.filesystem
      end

      def vfilesystem_update(vnodename,desc)
        vnode = vnode_get(vnodename)

        raise Lib::UninitializedResourceError, "filesystem" unless \
          vnode.filesystem

        vnode.filesystem.image = URI.encode(desc['image']) if desc['image']

        vnode.filesystem.shared = parse_bool(desc['shared']) if desc['shared']

        return vnode.filesystem
      end

      # Retrieve informations about the virtual node filesystem
      # ==== Returns
      # Resource::FileSystem object
      # ==== Exceptions
      #
      def vfilesystem_get(vnodename)
        vnode = vnode_get(vnodename)

        raise Lib::UninitializedResourceError, "filesystem" unless \
          vnode.filesystem

        return vnode.filesystem
      end

      # Get a compressed archive of the current filesystem (tgz)
      # WARNING: You have to contact the physical node the vnode is hosted on directly
      # ==== Returns
      # String object that describes the path to the archive
      # ==== Exceptions
      #
      def vfilesystem_image(vnodename)
        vnode = vnode_get(vnodename)
        archivepath = nil

        if target?(vnode)
          if vnode.filesystem.shared
            archivepath = Lib::FileManager::compress(vnode.filesystem.sharedpath)
          else
            archivepath = Lib::FileManager::compress(vnode.filesystem.path)
          end
        else
          raise Lib::ResourceError, "Please, contact the good PNode" \
        end

        return archivepath
      end

      # Execute and get the result of a command on a virtual node
      # ==== Attributes
      # * +command+ the command to be executed
      # ==== Returns
      # Hash object: { 'command' => <the command that was executed>, 'result' => <the result of the command> }
      # ==== Exceptions
      #
      def vnode_execute(vnodename,command)
        ret = ""
        if daemon?
          # >>> TODO: check if vnode exists
          vnode = vnode_get(vnodename)
          raise Lib::UninitializedResourceError, vnode.name unless \
            vnode.status == Resource::Status::RUNNING

          raise unless vnode

          ret = Daemon::Admin.vnode_run(vnode,command)
        end

        return ret
      end

      def vnetwork_sync(vnet, pnode, lock=true)
        if daemon?
          block = Proc.new do
            if !vnet.visibility.include?(pnode)
              vnet.visibility << pnode
              cl = NetAPI::Client.new(pnode.address.to_s)
              # Adding VNetwork on the pnode
              cl.vnetwork_create(vnet.name,vnet.address.to_string)

              # Adding VRoutes to the new VNetwork
              vnet.vroutes.values.each do |vroute|
                  vnetwork_sync(vroute.dstnet,pnode,false)
                cl.vroute_create(vnet.name,vroute.dstnet.name,vroute.gw.to_s)
              end
            end
          end

          if lock
            @@locks[:vnetsync][pnode] = Mutex.new unless \
              @@locks[:vnetsync][pnode]

            @@locks[:vnetsync][pnode].synchronize do
              block.call
            end
          else
            block.call
          end
        end
      end

      # Create a new virtual network specifying his range of IP address (IPv4 atm).
      # ==== Attributes
      # * +name+ the -unique- name of the virtual network (it will be used in a lot of methods)
      # * +address+ the address in the CIDR (10.0.0.1/24) or IP/NetMask (10.0.0.1/255.255.255.0) format
      # ==== Returns
      # Resource::VNetwork object
      # ==== Exceptions
      #
      def vnetwork_create(name,address)
        begin
          name = name.gsub(' ','_') if name
          vnetwork = Resource::VNetwork.new(address,name)
          if daemon?
            @daemon_resources.add_vnetwork(vnetwork)
            #Add a virtual interface connected on the network
            Lib::NetTools.set_new_nic(Daemon::Admin.get_vnetwork_addr(vnetwork),
                                      vnetwork.address.netmask)
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

      # Delete the virtual network
      # ==== Returns
      # Resource::VNetwork object
      # ==== Exceptions
      #
      def vnetwork_remove(name)
        vnetwork = vnetwork_get(name)

        vnetwork.vnodes.each_pair do |vnode,viface|
          viface_detach(vnode.name,viface.name)
        end

        if daemon?
          @daemon_resources.remove_vnetwork(vnetwork)

          vnetwork.visibility.each do |pnode|
            if (pnode.status == Resource::Status::RUNNING)
              cl = NetAPI::Client.new(pnode.address.to_s)
              cl.vnetwork_remove(vnetwork.name)
            end
          end
        end

        @node_config.vnetwork_remove(vnetwork)

        return vnetwork
      end

      # Delete every virtual networks
      # ==== Returns
      # Array of Resource::VNetwork objects
      # ==== Exceptions
      #
      def vnetworks_remove()
        vnetworks = nil
        if daemon?
          vnetworks = @daemon_resources.vnetworks
        else
          vnetworks = @node_config.vplatform.vnetworks
        end

        vnetworks.each_value { |vnetwork| vnetwork_remove(vnetwork.name) }

        return vnetworks
      end

      # Get the description of a virtual network
      # ==== Returns
      # Resource::VNetwork object
      # ==== Exceptions
      #
      def vnetwork_get(name,raising = true)
        name = name.gsub(' ','_')
        if daemon?
          vnetwork = @daemon_resources.get_vnetwork_by_name(name)
        else
          vnetwork = @node_config.vplatform.get_vnetwork_by_name(name)
        end

        raise Lib::ResourceNotFoundError, name if raising and !vnetwork

        return vnetwork
      end

      # Get the list of the the currently created virtual networks
      # ==== Returns
      # Array of Resource::VNetwork objects
      # ==== Exceptions
      #
      def vnetworks_get()
        vnetworks = nil
        if daemon?
          vnetworks = @daemon_resources.vnetworks
        else
          vnetworks = @node_config.vplatform.vnetworks
        end

        return vnetworks
      end

      # Create a virtual route ("go from <networkname> to <destnetwork> via <gatewaynode>").
      # The virtual route is applied to all the vnodes of <networkname>.
      # This method automagically set <gatewaynode> in gateway mode (if it's not already the case) and find the right virtual interface to set the virtual route on
      # ==== Attributes
      # * +destnetwork+ the name of the destination network
      # * +gatewaynode+ the name of the virtual node to use as a gateway
      # Deprecated: * +vnode+ the virtual node to set the virtual route on (optional)
      # ==== Returns
      # Resource::VRoute object
      # ==== Exceptions
      #
      def vroute_create(networksrc,networkdst,nodegw)
        begin
          srcnet = vnetwork_get(networksrc)
          destnet = vnetwork_get(networkdst)

          if daemon?
            gw = vnode_get(nodegw)
            gwaddr = gw.get_viface_by_network(srcnet)
            gwaddr = gwaddr.address if gwaddr
          else
            begin
              gw = IPAddress.parse(nodegw)
            rescue ArgumentError
              raise Lib::InvalidParameterError, nodegw
            end
            gwaddr = gw
            #destnet = @node_config.vplatform.get_vnetwork_by_address(networkdst) unless destnet
            #destnet = vnetwork_create(nil,networkdst) unless destnet
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
            raise Lib::InvalidParameterError, "#{gw.name}->#{srcnet}" unless \
              gw.connected_to?(srcnet)
            vnode_set_mode(gw.name,Resource::VNode::MODE_GATEWAY) unless \
              gw.gateway

            srcnet.visibility.each do |pnode|
              if (pnode.status == Resource::Status::RUNNING)
                cl = NetAPI::Client.new(pnode.address.to_s)
                vnetwork_sync(dstnet,pnode)
                cl.vroute_create(srcnet.name,destnet.name,gwaddr.to_s)
              end
            end
          end

          return vroute
        rescue Lib::AlreadyExistingResourceError
          raise
        rescue Exception
          destroy(vroute) if srcnet
          raise
        end
      end


      # Try to create every possible virtual routes between the current
      # set of virtual nodes automagically finding and setting up
      # the gateways to use
      # ==== Returns
      # Array of Resource::VRoute objects
      # ==== Exceptions
      #
      def vroute_complete()
        ret = []

        if daemon?
          # >>> TODO: Use vnetworks_get
          @daemon_resources.vnetworks.each_value do |srcnet|
            @daemon_resources.vnetworks.each_value do |destnet|
              next if srcnet == destnet
              gw = srcnet.perform_vroute(destnet)
              if gw
                vnode_mode_update(gw.name,Resource::VNode::MODE_GATEWAY) unless gw.gateway
                ret << vroute_create(srcnet.name,destnet.name,gw.name)
              end
            end
          end
        end

        return ret
      end

      # Load a configuration
      # ==== Attributes
      # * +data+ data to be applied
      # * +format+ the format of the data
      # ==== Returns
      # Resource::VPlatform object
      # ==== Exceptions
      #
      def vplatform_create(format,data)
        # >>> TODO: check if there is already a created vplatform
        raise Lib::InvalidParameterError unless daemon?
        raise Lib::MissingParameterError, 'data' unless data

        parser = nil
        desc = {}

        case format.upcase
        when 'XML'
          parser = TopologyStore::XMLReader.new
        when 'JSON'
          desc = JSON.parse(data)
        when 'SIMGRID'
          parser = TopologyStore::SimgridReader.new('file:///home/lsarzyniec/rootfs.tar.bz2')
        else
          raise Lib::InvalidParameterError, format 
        end

        if desc.empty?
          desc = parser.parse(data)
          #raise PP.pp(hash['vplatform'])
        end

        raise InvalidParameterError, data unless Lib::Validator.validate(hash)

        # Initialize the pnodes (if there is some)
=begin
        if desc['vplatform']['pnodes']
          pnodes = []
          desc['vplatform']['pnodes'].each do |pnodedesc|
            pnodes << pnode_create!(pnodedesc['address'], pnodedesc)
          end

          pnodes.each do |pnode|
            while pnode.status != Resource::Status::READY
              sleep(0.2)
            end
          end
        end
=end

        # Creating vnetworks
        if desc['vplatform']['vnetworks']
          desc['vplatform']['vnetworks'].each do |vnetdesc|
            vnetwork_create(vnetdesc['name'],vnetdesc['address'])
          end
        end

        # Creating the vnodes
        starting_vnodes = []
        if desc['vplatform']['vnodes']
          desc['vplatform']['vnodes'].each do |vnodedesc|
            ret = vnode_create!(vnode['name'], vnodedesc)
            starting_vnodes << ret if \
              vnodedesc['status'] == Resource::Status::RUNNING
          end
        end

        # Creating VRoutes
        #vroute_complete()
        if desc['vplatform']['vnetworks']
          desc['vplatform']['vnetworks'].each do |vnetdesc|
            if vnetdesc['vroutes']
              vnetdesc['vroutes'].each do |vroutedesc|
                vroute_create(vroutedesc['networksrc'],vroutedesc['networkdst'],
                  vroutedesc['gateway']
                )
              end
            end
          end
        end

        starting_vnodes.each do |vnode|
          while vnode.status != Resource::Status::READY
            sleep(0.2)
          end
        end

        return @daemon_resources
      end

      # Get the description file of the current platform in a specified format (JSON if not specified)
      # ==== Attributes
      # * +format+ the format of the returned data
      # ==== Returns
      # String value that reprents the platform in the _format_ form
      # ==== Exceptions
      #
      def vplatform_get(format)
        format = '' unless format
        visitor = nil
        ret = ''

        case format.upcase
        when 'XML'
          visitor = TopologyStore::XMLWriter.new
        when 'JSON', ''
          visitor = TopologyStore::HashWriter.new
          ret += JSON.pretty_generate(visitor.visit(@daemon_resources))
        else
          raise Lib::InvalidParameterError, format 
        end

        if ret.empty?
          return visitor.visit(@daemon_resources)
        else
          return ret
        end
      end

      protected

      # Check if the server is launched in daemon mode
      # ==== Returns
      # Boolean value
      #
      def daemon?
        @mode == MODE_DAEMON
      end

      # Guess that we are in a local context
      # ==== Attributes
      # * +param+ IP address (String) or VNode
      # ==== Returns
      # Boolean value
      def target?(param)
        ret = false
        if daemon?
          target = nil
          if param.is_a?(Resource::VNode)
            target = param.host.address.to_s if param.host
          elsif param.is_a?(String)
            begin
              target = Resolv.getaddress(param)
            rescue Resolv::ResolvError
              raise Lib::InvalidParameterError, param
            end
          elsif param == nil
            ret = true
          end
          ret = Lib::NetTools.localaddr?(target) if target
        else
          ret = true
        end
        return ret
      end

      # Get a new version of the hash with downcase keys
      # ==== Attributes
      # * +hash+ The Hash object
      # ==== Returns
      # New Hash object
      def downkeys(hash)
        if hash.is_a?(Hash)
          hash.each do |k,v|
            hash[k.downcase] = downkeys(v)
            hash.delete(k) unless k.downcase == k
          end
        end

        return hash
      end

      def updateobj_pnode(pnode,hash)
        pnode.memory.capacity = hash['memory']['capacity'].split[0].to_i
        pnode.memory.swap = hash['memory']['swap'].split[0].to_i

        hash['cpu']['cores'].each do |core|
          core['frequencies'].collect!{ |val| val.split[0].to_i * 1000 }

          core['frequency'] = core['frequency'].split[0].to_i * 1000

          pnode.cpu.add_core(
            core['physicalid'],core['coreid'],
            core['frequency'], core['frequencies']
          )
        end

        hash['cpu']['critical_cache_links'].each do |link|
          pnode.cpu.add_critical_cache_link(link)
        end
      end

      def updateobj_vnode(vnode,hash)
        vnode.filesystem.sharedpath = hash['vfilesystem']['sharedpath']
        vnode.filesystem.path = hash['vfilesystem']['path']

        if vnode.vcpu
          #vnode.vcpu.pcpu = vnode.host.cpu if vnode.host
          i = 0
          vnode.vcpu.vcores.each_value do |vcore|
            vcore.pcore = hash['vcpu']['vcores'][i]['pcore']
            vcore.frequency = hash['vcpu']['vcores'][i]['frequency'].split[0].to_i * 1000
            i += 1
          end
        end
      end

      def parse_bool(param)
        ret = false

        if param.is_a?(TrueClass) or param.is_a?(FalseClass)
          ret = param
        elsif param.nil? or param.empty?
          ret = false
        elsif ['no','false','disable','0'].include?(param.to_s.strip.downcase)
          ret = false
        else
          ret = true
        end

        return ret
      end

      # Destroy (clean) a resource
      def destroy(resource)
        if daemon?
          @daemon_resources.destroy(resource)
        end
        @node_config.destroy(resource)
      end
    end
  end
end
