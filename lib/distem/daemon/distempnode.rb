require 'thread'
require 'socket'
require 'ipaddress'
require 'json'
require 'pp'

module Distem
  module Daemon
    class DistemPnode
      # The NodeConfig object that allows to apply virtual resources specifications on physical nodes
      attr_reader  :node_config

      MAX_VNODES_SIMULT_START_ON_PNODE = 40
      @@semvnodestart_pnodelock = Mutex.new
      @@semvnodestart_pnode = {}



      @@lockslock = Mutex.new
      @@locks = {
        :vnetsync => {},
      }

      @@threads = {
        :pnode_init => {},
        :vnode_start => {},
        :vnode_stop => {},
      }

      def initialize
        #Thread::abort_on_exception = true
        @node_name = Socket::gethostname
        @node_config = Node::ConfigManager.new
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
        raise Lib::ResourceError, "Please, contact the good PNode" unless target?(target)
        begin
          async = parse_bool(async)
          pnode = @node_config.pnode
          Node::Admin.init_node(pnode,desc)
          @node_config.vplatform.add_pnode(pnode)
          pnode.status = Resource::Status::RUNNING
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
        raise Lib::ResourceError, "Please, contact the good PNode" unless target?(target)
        pnode = pnode_get(target)

        if desc['algorithms']
          if desc['algorithms']['cpu']
            algo = desc['algorithms']['cpu'].upcase
            raise InvalidParameterError "algorithms/cpu" unless \
              [Algorithm::CPU::GOV.upcase,
              Algorithm::CPU::HOGS.upcase].include?(algo)
            pnode.algorithms[:cpu] = algo
            return {'algorithms' => {'cpu'=> algo }}
          end
        end
      end

      # Quit distem on a physical machine (remove everything that was created)
      # ==== Returns
      # Resource::PNode object
      # ==== Exceptions
      #
      def pnode_quit(target)
        raise Lib::ResourceError, "Please, contact the good PNode" unless target?(target)
        pnode = pnode_get(target,false)
        pnode.status = Resource::Status::CONFIGURING
        vnodes_remove()
        vnetworks_remove()
        Lib::FileManager::clean_cache
        Node::Admin.quit_node()
        pnode.status = Resource::Status::READY
        return pnode
      end

      # Get the description of a virtual node
      #
      # ==== Attributes
      #
      def pnode_get(hostname, raising = true)
        pnode = nil

        if hostname and Lib::NetTools.localaddr?(hostname)
          pnode = @node_config.pnode
        else
          hostname = '' unless hostname
          begin
            address = Resolv.getaddress(hostname)
          rescue Resolv::ResolvError
            raise Lib::InvalidParameterError, hostname
          end
          pnode = @node_config.vplatform.get_pnode_by_address(address)
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
        return @node_config.vplatform.pnodes
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
          @node_config.vnode_add(vnode)
          vnode_update(vnode.name,desc,async)
          return vnode
        rescue Lib::AlreadyExistingResourceError
          raise
        rescue Exception
          destroy(vnode) if vnode
          raise
        end

      end

      def vnodes_stop()
        vnodes = vnodes_get()
        tids = []
        vnodes.each_value { |vnode|
          tids << Thread.new {
            vnode_status_update(vnode.name, Resource::Status::READY)
          }
        }
        tids.each { |tid| tid.join }
        return vnodes
      end

      # Update the vnode resource
      def vnode_update(name,desc,async=false)
        async = parse_bool(async)
        vnode = vnode_get(name)
        downkeys(desc)
        vnode.sshkey = desc['ssh_key'] if desc['ssh_key'] and \
        (desc['ssh_key'].is_a?(Hash) or desc['ssh_key'].nil?)
        vnode_attach(vnode.name,desc['host']) if desc['host']
        vfilesystem_create(vnode.name,desc['vfilesystem']) if desc['vfilesystem']
        if desc['vcpu']
          if vnode.vcpu
            vcpu_update(vnode.name,desc['vcpu'])
          else
            vcpu_create(vnode.name,desc['vcpu'])
          end
        end
        vnode.vmem = desc['vmem'] if desc['vmem']
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
        @node_config.vnode_remove(vnode)
        return ret
      end

      def vnode_attach(name,host)
        vnode = vnode_get(name)
        pnode = @node_config.pnode
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

      # Get the description of a virtual node
      # ==== Returns
      # Resource::VNode object
      # ==== Exceptions
      #
      def vnode_get(name, raising = true)
        name = name.gsub(' ','_')
        vnode = @node_config.get_vnode(name)
        raise Lib::ResourceNotFoundError, name if raising and !vnode
        return vnode
      end

      # Change the status of the -previously created- virtual node.
      #
      # ==== Attributes
      # * +status+ the status to set: "Running", "Ready", or "Down"
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
        elsif status.upcase == Resource::Status::DOWN
          vnode = vnode_shutdown(name,async)
        else
          raise Lib::InvalidParameterError, status
        end

        return vnode
      end

      # Same as vnode_set_status(name,Resource::Status::RUNNING,properties)
      def vnode_start(name,async=false)
        async = parse_bool(async)
        vnode = vnode_get(name)
        raise Lib::ResourceError, "Please, contact the good PNode" unless target?(vnode)
        raise Lib::BusyResourceError, vnode.name if \
          vnode.status == Resource::Status::CONFIGURING

        raise Lib::ResourceError, "#{vnode.name} already running" if \
          vnode.status == Resource::Status::RUNNING

        vnode.status = Resource::Status::CONFIGURING
        vnode.host = @node_config.pnode unless vnode.host
        vnode.vcpu.attach if vnode.vcpu and !vnode.vcpu.attached?
        @node_config.vnode_start(vnode)
        vnode.status = Resource::Status::RUNNING

        return vnode
      end

      # Same as vnode_set_status(name,Resource::Status::READY,properties)
      def vnode_stop(name, async=false)
        async = parse_bool(async)
        vnode = vnode_get(name)
        raise Lib::ResourceError, "Please, contact the good PNode" unless target?(vnode)
        raise Lib::BusyResourceError, vnode.name if \
          vnode.status == Resource::Status::CONFIGURING
        raise Lib::UninitializedResourceError, vnode.name if \
          vnode.status == Resource::Status::INIT

        vnode.status = Resource::Status::CONFIGURING
        @node_config.vnode_stop(vnode)
        vnode.status = Resource::Status::READY
        return vnode
      end

       # Same as vnode_set_status(name,Resource::Status::DOWN,properties)
      def vnode_shutdown(name, async=false)
        async = parse_bool(async)
        vnode = vnode_get(name)
        raise Lib::ResourceError, "Please, contact the good PNode" unless target?(vnode)
        raise Lib::BusyResourceError, vnode.name if \
          vnode.status == Resource::Status::CONFIGURING
        raise Lib::UninitializedResourceError, vnode.name if \
          vnode.status == Resource::Status::INIT

        vnode.status = Resource::Status::CONFIGURING
        @node_config.vnode_stop(vnode, false)
        vnode.status = Resource::Status::DOWN
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
        return @node_config.vplatform.vnodes
      end

      # Remove every virtual nodes
      # ==== Returns
      # Array of Resource::PNode objects
      # ==== Exceptions
      #
      def vnodes_remove()
        vnodes = vnodes_get()
        tids = []
        vnodes.each_value { |vnode|
          tids << Thread.new {
            vnode_remove(vnode.name)
          }
        }
        tids.each { |tid| tid.join }
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

          raise Lib::MissingParameterError, "address&vnetwork" if \
          ((!desc['address'] or desc['address'].empty?) \
           or (!desc['vnetwork'] or desc['vnetwork'].empty?))
          vplatform = @node_config.vplatform

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

        voutput_update(vnode.name,viface.name,desc['output']) if desc['output']
        vinput_update(vnode.name,viface.name,desc['input']) if desc['input']

        return viface
      end

      def vinput_get(vnodename,vifacename, raising = true)
        viface = viface_get(vnodename,vifacename)

        raise Lib::UninitializedResourceError, 'input' if raising and !viface.vinput

        return viface.vinput
      end

      def vinput_update(vnodename,vifacename,desc)
        vnode = vnode_get(vnodename)
        raise Lib::ResourceError, "Please, contact the good PNode" unless target?(vnode)
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
          @node_config.vnode_reconfigure(vnode)
          vnode.status = Resource::Status::RUNNING
        end

        return viface.vinput
      end

      def voutput_get(vnodename,vifacename, raising = true)
        viface = viface_get(vnodename,vifacename)

        raise Lib::UninitializedResourceError, 'voutput' if raising and !viface.voutput

        return viface.voutput
      end

      def voutput_update(vnodename,vifacename,desc)
        vnode = vnode_get(vnodename)
        raise Lib::ResourceError, "Please, contact the good PNode" unless target?(vnode)
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
          @node_config.vnode_reconfigure(vnode)
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
          raise Lib::ResourceError, "Please, contact the good PNode" unless target?(vnode)
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
            @node_config.vnode_reconfigure(vnode)
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
          raise Lib::ResourceError, "Please, contact the good PNode" unless target?(vnode)
          vcpu = vcpu_get(vnode.name)

          downkeys(desc)

          if desc['vcores']
            raise Lib::InvalidParameterError, 'vcores' unless desc['vcores'].is_a?(Array)
            freq = desc['vcores'][0]['frequency'].split(0).to_f || 1.0
          else
            freq = desc['frequency'].to_f || 1.0
          end

          freq = freq * 1000 if freq > 1

          vcpu.update_vcores(freq)

          if vnode.status == Resource::Status::RUNNING
            vnode.status = Resource::Status::CONFIGURING
            @node_config.vnode_reconfigure(vnode)
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
        desc['cow'] = parse_bool(desc['cow'])

        vnode.filesystem = Resource::FileSystem.new(vnode,desc['image'],desc['shared'],desc['cow'])

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
        raise Lib::ResourceError, "Please, contact the good PNode" unless target?(vnode)
        archivepath = nil
        if vnode.filesystem.shared
          archivepath = Lib::FileManager::compress(vnode.filesystem.sharedpath)
        else
          archivepath = Lib::FileManager::compress(vnode.filesystem.path)
        end
        return archivepath
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
        vnetworks = @node_config.vplatform.vnetworks
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
        vnetwork = @node_config.vplatform.get_vnetwork_by_name(name)
        raise Lib::ResourceNotFoundError, name if raising and !vnetwork
        return vnetwork
      end

      # Get the list of the the currently created virtual networks
      # ==== Returns
      # Array of Resource::VNetwork objects
      # ==== Exceptions
      #
      def vnetworks_get()
        return @node_config.vplatform.vnetworks
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
          begin
            gw = IPAddress.parse(nodegw)
          rescue ArgumentError
            raise Lib::InvalidParameterError, nodegw
          end
          gwaddr = gw
          #destnet = @node_config.vplatform.get_vnetwork_by_address(networkdst) unless destnet
          #destnet = vnetwork_create(nil,networkdst) unless destnet

          raise Lib::ResourceNotFoundError, networksrc unless srcnet
          raise Lib::ResourceNotFoundError, networkdst unless destnet
          raise Lib::ResourceNotFoundError, nodegw unless gw
          raise Lib::InvalidParameterError, nodegw unless gwaddr

          vroute = srcnet.get_vroute(destnet)
          unless vroute
            vroute = Resource::VRoute.new(srcnet,destnet,gwaddr)
            srcnet.add_vroute(vroute)
          end
          return vroute
        rescue Lib::AlreadyExistingResourceError
          raise
        rescue Exception
          destroy(vroute) if srcnet
          raise
        end
      end

      def set_peers_latencies(vnodes, matrix)
        tids = []
        matrix.each_pair { |vnode_name,destinations|
          tids << Thread.new {
            vnode = vnode_get(vnode_name)
            vnode.vifaces[0].latency_filters = destinations
            if vnode.status == Resource::Status::RUNNING
              vnode.status = Resource::Status::CONFIGURING
              @node_config.vnode_reconfigure(vnode)
              vnode.status = Resource::Status::RUNNING
            end
          }
        }
        tids.each { |tid| tid.join }
        return true
      end

      def set_global_etchosts(data)
        shared_fs = []
        private_fs = []
        @node_config.vplatform.vnodes.each_value { |vnode|
          if vnode.filesystem.shared
            shared_fs << vnode
          else
            private_fs << vnode
          end
        }
        @node_config.set_global_etchosts(shared_fs.first, data) if !shared_fs.empty?
        private_fs.each {|vnode|
          @node_config.set_global_etchosts(vnode, data)
        } if !private_fs.empty?
      end

      protected


      # Guess that we are in a local context
      # ==== Attributes
      # * +param+ IP address (String) or VNode
      # ==== Returns
      # Boolean value
      def target?(param)
        ret = false
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
        @node_config.destroy(resource)
      end
    end
  end
end
