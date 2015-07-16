require 'thread'
require 'socket'
require 'ipaddress'
require 'json'
require 'pp'
require 'resolv'
require 'zlib'
require 'base64'
require 'cgi'

module Distem
  module Daemon
    class DistemCoordinator
      # The VPlatform object that describes each resources in the experimental platform
      attr_reader :daemon_resources
      @vnet_id = nil

      @@lockslock = Mutex.new
      @@locks = {
        :vnetsync => {},
      }

      @@threads = {
        :pnode_init => {},
        :vnode_stop => {},
      }
      # See https://en.wikipedia.org/wiki/MAC_address#Address_details for allowed addresses
      MAC_PREFIX = "fe:#{rand(256).to_s(16).rjust(2,"0")}:#{rand(256).to_s(16).rjust(2,"0")}"
      @@mac_id = 0
      @@mac_id_lock = Mutex.new

      @@vxlan_id = 1
      @@vxlan_id_lock = Mutex.new

      @@network_mode = nil

      WINDOW_SIZE = 250

      def initialize(network_mode,root_iface)
        #Thread::abort_on_exception = true
        @node_name = Socket::gethostname
        @daemon_resources = Resource::VPlatform.new
        @daemon_resources_lock = Mutex.new
        @vnet_id = 0
        @event_trace = Events::Trace.new
        @event_manager = Events::EventManager.new(@event_trace)
        @@network_mode = network_mode
        @@root_iface = root_iface
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
      def pnode_create(targets,desc={},async=false)
        l = lambda { |target|
          begin
            async = parse_bool(async)
            pnode = @daemon_resources.get_pnode_by_address(target)
            pnode = Resource::PNode.new(target) unless pnode
            @daemon_resources.add_pnode(pnode)
            desc['set_bridge'] = (@@network_mode == 'classical')
            block = Proc.new {
              Admin.pnode_run_server(pnode)
              cl = NetAPI::Client.new(target, 4568)
              ret = cl.pnode_init(nil,desc,async)
              # here ret should always contains one element
              updateobj_pnode(pnode,ret)
              pnode.status = Resource::Status::RUNNING
            }

            if async
              #thr = @@threads[:pnode_init][pnode.address.to_s] = Thread.new {
              @@threads[:pnode_init][pnode.address.to_s] = Thread.new {
                block.call
              }
              #thr.abort_on_exception = true
            else
              block.call
            end

            pnode_update(pnode.address.to_s,desc)

            return pnode
          rescue Lib::AlreadyExistingResourceError
            raise
          rescue Exception
            destroy(pnode) if pnode
            raise
          end
        }

        if targets.is_a?(Array) then
          threads_info = {}
          targets.each { |target|
            threads_info[target] = {}
            threads_info[target]['tid'] = Thread.new {
              threads_info[target]['ret'] = l.call(target)
            }
          }
          ret = []
          threads_info.each_value { |host|
            host['tid'].join
            ret << host['ret']
          }
          return ret
        else
          return [l.call(targets)]
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
            return {'algorithms' => {'cpu'=> algo }}
          end
        end
      end

      # Wait for a PNode to be ready
      def pnode_wait(target)
        pnode = pnode_get(target)

        @@threads[:pnode_init][pnode.address.to_s].join if \
        @@threads[:pnode_init][pnode.address.to_s]
      end

      # Quit distem on all the physical machines (remove everything that was created)
      # ==== Returns
      # Array of Resource::PNode objects
      # ==== Exceptions
      #
      def pnodes_quit()
        ret = @daemon_resources.pnodes.dup
        first_node = Resolv.getaddress(@node_name).to_s
        tids = []

        distant_quit = lambda { |target|
          pnode = pnode_get(target,false)
          cl = NetAPI::Client.new(target, 4568)
          cl.pnode_quit(target)
          @daemon_resources.remove_pnode(pnode)
        }
        @daemon_resources.pnodes.each_value { |pnode|
          tids << Thread.new {
            pnode.status = Resource::Status::CONFIGURING
            vnodes = []
            @daemon_resources.vnodes.each_value { |vnode|
              if vnode.host != nil && (vnode.host.address.to_s == pnode.address.to_s)
                vnodes << vnode
              end
            }
            vn = vnodes.map { |vnode| vnode.name }
            vnodes_stop(vn, false)
            vnodes_remove(vn)

            distant_quit.call(pnode.address.to_s) if pnode.address.to_s != first_node
            pnode.status = Resource::Status::READY
          }
        }
        tids.each { |tid| tid.join }
        distant_quit.call(first_node)
        return ret
      end

      # Get the description of a virtual node
      #
      # ==== Attributes
      #
      def pnode_get(hostname, raising = true)
        pnode = nil

        hostname = '' unless hostname
        begin
          address = Resolv.getaddress(hostname)
        rescue Resolv::ResolvError
          raise Lib::InvalidParameterError, hostname
        end
        pnode = @daemon_resources.get_pnode_by_address(address)
        raise Lib::ResourceNotFoundError, hostname if raising and !pnode
        return pnode
      end

      # Get the list of the the currently created physical nodes
      # ==== Returns
      # Array of Resource::PNode objects
      # ==== Exceptions
      #
      def pnodes_get()
        return @daemon_resources.pnodes
      end

      # Launch a set of probes on every PNode
      def pnodes_launch_probes(desc,_)
        w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
        @daemon_resources.pnodes.each_value {|pnode|
          block = Proc.new {
            cl = NetAPI::Client.new(pnode.address.to_s, 4568)
            cl.pnodes_launch_probes(desc, Time.now.to_f)
          }
          w.add(block)
        }
        w.run
      end


      # Restart the probes on every PNode
      def pnodes_restart_probes()
        w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
        @daemon_resources.pnodes.each_value {|pnode|
          block = Proc.new {
            cl = NetAPI::Client.new(pnode.address.to_s, 4568)
            cl.pnodes_restart_probes()
          }
          w.add(block)
        }
        w.run
      end

      # Stop the probes on every PNode
      def pnodes_stop_probes()
        w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
        @daemon_resources.pnodes.each_value {|pnode|
          block = Proc.new {
            cl = NetAPI::Client.new(pnode.address.to_s, 4568)
            cl.pnodes_stop_probes()
          }
          w.add(block)
        }
        w.run
      end

      # Delete the probes on every PNode
      def pnodes_delete_probes()
        w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
        @daemon_resources.pnodes.each_value {|pnode|
          block = Proc.new {
            cl = NetAPI::Client.new(pnode.address.to_s, 4568)
            cl.pnodes_delete_probes()
          }
          w.add(block)
        }
        w.run
      end

      # Get the data collected bu the probes
      # ==== Returns
      # Hash with one entry per probe. Every entry is an Array containing a time series
      def pnodes_get_probes_data()
        result = {}
        w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
        @daemon_resources.pnodes.each_value {|pnode|
          block = Proc.new {
            cl = NetAPI::Client.new(pnode.address.to_s, 4568)
            result[Resolv.getname(pnode.address)] = cl.pnodes_get_probes_data()
          }
          w.add(block)
        }
        w.run
        return result
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

      # Get the description of a vnode
      def vnode_get_info(vnodename)
        vnode = vnode_get(vnodename).dup
        if vnode.filesystem && vnode.filesystem.image
          vnode.filesystem.image = CGI.unescape(vnode.filesystem.image)
        end
        return vnode
      end

      # Get the description of the vnodes
      def vnodes_get_info()
        vnodes = vnodes_get().dup
        vnodes.each_value { |vnode|
          if vnode.filesystem && vnode.filesystem.image
            vnode.filesystem.image = CGI.unescape(vnode.filesystem.image)
          end
        }
        return vnodes
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
      def vnode_create(names,desc,ssh_key={},async=false)
        begin
          async = parse_bool(async)
          downkeys(desc)
          raise Lib::ArgumentMissingError "names" if !names
          names = [names] if !names.is_a?(Array)
          names = names.map { |name| name.gsub(' ','_') }
          vnodes = []
          names.each { |name|
            vnode = Resource::VNode.new(name,ssh_key)
            @daemon_resources.add_vnode(vnode)
            vnodes << vnode
          }
          vnode_update(names,desc,async)
          return vnodes
        rescue Lib::AlreadyExistingResourceError
          raise
        rescue Exception
          raise
        end

      end

      # Update the vnode resource
      def vnode_update(names,description,async=false)
        async = parse_bool(async)
        names = [names] if !names.is_a?(Array)
        vnodes = []
        downkeys(description)
        names.each { |name|
          desc = Marshal.load(Marshal.dump(description))
          vnode = vnode_get(name)
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
          if desc['vifaces']
            desc['vifaces'].each do |ifdesc|
              if vnode.get_viface_by_name(ifdesc['name'])
                viface_update(vnode.name,ifdesc['name'],ifdesc)
              else
                viface_create(vnode.name,ifdesc['name'],ifdesc)
              end
            end
          end
          vmem_create(vnode.name, desc['vmem']) if desc['vmem']
          vnode_mode_update(vnode.name,desc['mode']) if desc['mode']
          vnodes << vnode
        }
        vnode_status_update(names,description['status'],async) if description['status']
        return vnodes
      end

      # Remove the virtual node ("Cascade" removing -> remove all the vroutes it apears as gateway)
      # ==== Returns
      # Resource::VNode object
      # ==== Exceptions
      #
      def vnode_remove(names)
        names = [names] if !names.is_a?(Array)
        vnodes = names.map { |name| vnode_get(name) }
        ret = vnodes.dup
        vnodes_to_remove = []
        vnodes.each { |vnode|
          raise Lib::BusyResourceError, "#{vnode.name}/running" if vnode.status == Resource::Status::RUNNING
          vnode.vifaces.each { |viface| viface_remove(vnode.name,viface.name) }
          @daemon_resources_lock.synchronize {
            vnode.remove_vcpu()
            vnode.remove_vmem() if vnode.vmem
          }
          vnodes_to_remove << vnode if vnode.host
          @daemon_resources.remove_vnode(vnode)
        }
        vnodesperpnode = Hash.new
        vnodes_to_remove.each { |vnode|
          vnodesperpnode[vnode.host.address.to_s] = [] if !vnodesperpnode.has_key?(vnode.host.address.to_s)
          vnodesperpnode[vnode.host.address.to_s] << vnode
        }
        w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
        vnodesperpnode.each { |address,vn|
          block = Proc.new {
            cl = NetAPI::Client.new(address, 4568)
            cl.vnodes_remove(vn)
          }
          w.add(block)
        }
        w.run
        return ret
      end

      # Remove the given virtual nodes, or every if names is nil
      # ==== Returns
      # Array of Resource::PNode objects
      # ==== Exceptions
      #
      def vnodes_remove(names)
        names = @daemon_resources.vnodes.keys if !names
        return vnode_remove(names)
      end

      def vnode_attach(name,host)
        vnode = vnode_get(name)
        pnode = @daemon_resources.get_pnode_by_address(host)

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
        vnode = @daemon_resources.get_vnode(name)
        raise Lib::ResourceNotFoundError, name if raising and !vnode
        return vnode
      end

      # Change the status of the -previously created- virtual node.
      #
      # ==== Attributes
      # * +status+ the status to set: "Running" or "Down"
      # * +properties+ async
      # ==== Returns
      # Resource::VNode object
      # ==== Exceptions
      #
      def vnode_status_update(names,status,async=false)
        async = parse_bool(async)
        vnodes = []
        raise Lib::InvalidParameterError, status unless \
        Resource::Status.valid?(status)
        if status.upcase == Resource::Status::RUNNING
          vnodes = vnodes_start(names,async)
        elsif status.upcase == Resource::Status::DOWN
          vnodes = vnodes_stop(names,async)
        elsif status.upcase == Resource::Status::INIT
          #Just do nothing
        else
          raise Lib::InvalidParameterError, status
        end

        return vnodes
      end

      # Same as vnode_set_status(name,Resource::Status::RUNNING,properties)
      def vnode_start(names,async=false)
        async = parse_bool(async)
        vnodes = []
        vnodes_previous_status = {}
        names.each { |name|
          vnode = vnode_get(name)
          raise Lib::BusyResourceError, vnode.name if \
          vnode.status == Resource::Status::CONFIGURING

          raise Lib::ResourceError, "#{vnode.name} already running" if \
          vnode.status == Resource::Status::RUNNING
          vnodes_previous_status[name] = vnode.status

          vnode.status = Resource::Status::CONFIGURING
          if (vnodes_previous_status[name] != Resource::Status::DOWN)
            @daemon_resources_lock.synchronize {
              if vnode.host
                if ((vnode.host.local_vifaces + vnode.vifaces.length) > Node::Admin.vifaces_max)
                  raise Lib::UnavailableResourceError, "Maximum ifaces number of #{Node::Admin.vifaces_max} reached"
                else
                  vnode.host.local_vifaces += vnode.vifaces.length
                end
              else
                vnode.host = @daemon_resources.get_pnode_available(vnode)
              end
              vnode.host.memory.allocate({:mem => vnode.vmem.mem, :swap => vnode.vmem.swap}) if vnode.vmem
              vnode.vcpu.attach if vnode.vcpu and !vnode.vcpu.attached?
            }
          end
          vnodes << vnode
        }
        vnodesperpnode = Hash.new
        vnodes.each { |vnode|
          vnodesperpnode[vnode.host.address.to_s] = [] if !vnodesperpnode.has_key?(vnode.host.address.to_s)
          vnodesperpnode[vnode.host.address.to_s] << vnode
        }
        blocks = []
        vnodesperpnode.each { |address,vn|
          blocks << Proc.new {
            vnodes_to_start = vn.map { |vnode| vnode if (vnodes_previous_status[vnode.name] == Resource::Status::DOWN) }.compact
            vnodes_to_create = vn.map { |vnode| vnode if (vnodes_previous_status[vnode.name] != Resource::Status::DOWN) }.compact
            cl = NetAPI::Client.new(address, 4568)
            ret = nil
            if vnodes_to_start
              # Just restart the node
              n = vnodes_to_start.map { |vnode| vnode.name }
              ret = cl.vnodes_start(n, async)
              vnodes_to_start.each_index { |i|
                updateobj_vnode(vnodes_to_start[i],ret[i])
                vnodes_to_start[i].status = Resource::Status::RUNNING
              }
            end
            if vnodes_to_create
              descs = []
              # Create VNetworks on remote PNode
              # TODO: vectorize vnetwork_sync
              vnodes_to_create.each { |vnode|
                vnode.get_vnetworks.each do |vnet|
                  vnetwork_sync(vnet,vnode.host)
                end
                desc = TopologyStore::HashWriter.new.visit(vnode)
                desc['status'] = Resource::Status::RUNNING
                descs << desc
              }

              n = vnodes_to_create.map { |vnode| vnode.name }
              # we want the node to be runned
              ret = cl.vnodes_create(n,descs)
              vnodes_to_create.each_index { |i|
                updateobj_vnode(vnodes_to_create[i],ret[i])
                vnodes_to_create[i].status = Resource::Status::RUNNING
              }
            end
          }
        }

        w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
        if async
          thr = Thread.new {
            blocks.each { |block|
              w.add(block)
            }
            w.run
          }
          thr.abort_on_exception = true
        else
          blocks.each { |block|
            w.add(block)
          }
          w.run
        end

        return vnodes
      end

      def vnodes_start(names, async=false)
        async = parse_bool(async)
        return vnode_start(names, async)
      end

      # Same as vnode_set_status(name,Resource::Status::DOWN,properties)
      def vnode_stop(names, async=false)
        async = parse_bool(async)
        names = [names] if !names.is_a?(Array)
        vnodes = names.map { |name| vnode_get(name) }
        status = {}

        vnodes.each { |vnode|
          status[vnode.name] = vnode.status
          raise Lib::BusyResourceError, vnode.name if vnode.status == Resource::Status::CONFIGURING
#          raise Lib::UninitializedResourceError, vnode.name if vnode.status == Resource::Status::INIT
          vnode.status = Resource::Status::CONFIGURING
        }
        block = Proc.new {
          vnodesperpnode = Hash.new
          vnodes.each { |vnode|
            #Discard vnodes that are not yet initialized
            if status[vnode.name] != Resource::Status::INIT
              vnodesperpnode[vnode.host.address.to_s] = [] if !vnodesperpnode.has_key?(vnode.host.address.to_s)
              vnodesperpnode[vnode.host.address.to_s] << vnode
            end
          }
          w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
          vnodesperpnode.each { |address,vn|
            sub_block = Proc.new {
              n = vn.map { |vnode| vnode.name }
              Distem.client(address, 4568) do |cl|
                cl.vnodes_stop(n,false)
              end
            }
            w.add(sub_block)
          }
          w.run
          vnodes.each { |vnode|
            vnode.status = Resource::Status::DOWN
          }
        }
        if async
          thr = Thread.new {
            block.call
          }
          thr.abort_on_exception = true
        else
            block.call
        end
        return vnodes
      end

      def vnodes_stop(names, async=false)
        async = parse_bool(async)
        names = @daemon_resources.vnodes if !names
        return vnode_stop(names,async)
      end

      def vnodes_freeze(names, async=false)
        async = parse_bool(async)

        vnodes = names.map { |name| vnode_get(name) }
        vnodes.each { |vnode|
          raise Lib::BusyResourceError, vnode.name if vnode.status == Resource::Status::CONFIGURING
          raise Lib::UninitializedResourceError, vnode.name if vnode.status == Resource::Status::INIT
          vnode.status = Resource::Status::CONFIGURING
        }

        block = Proc.new {
          vnodesperpnode = Hash.new
          vnodes.each { |vnode|
            vnodesperpnode[vnode.host.address.to_s] = [] if !vnodesperpnode.has_key?(vnode.host.address.to_s)
            vnodesperpnode[vnode.host.address.to_s] << vnode
          }
          w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
          vnodesperpnode.each { |address,vn|
            sub_block = Proc.new {
              n = vn.map { |vnode| vnode.name }
              Distem.client(address, 4568) do |cl|
                cl.vnodes_freeze(n, async)
              end
            }
            w.add(sub_block)
          }
          w.run

          vnodes.each { |vnode|
            vnode.status = Resource::Status::FROZEN
          }
        }

        if async
          thr = Thread.new {
            block.call
          }
          thr.abort_on_exception = true
        else
          block.call
        end

        return vnodes
      end

      def vnodes_unfreeze(names, async=false)
        async = parse_bool(async)

        vnodes = names.map { |name| vnode_get(name) }
        vnodes.each { |vnode|
          raise Lib::BusyResourceError, vnode.name if vnode.status != Resource::Status::FROZEN
          vnode.status = Resource::Status::CONFIGURING
        }

        block = Proc.new {
          vnodesperpnode = Hash.new
          vnodes.each { |vnode|
            vnodesperpnode[vnode.host.address.to_s] = [] if !vnodesperpnode.has_key?(vnode.host.address.to_s)
            vnodesperpnode[vnode.host.address.to_s] << vnode
          }
          w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
          vnodesperpnode.each { |address,vn|
            sub_block = Proc.new {
              n = vn.map { |vnode| vnode.name }
              Distem.client(address, 4568) do |cl|
                cl.vnodes_unfreeze(n, async)
              end
            }
            w.add(sub_block)
          }
          w.run

          vnodes.each { |vnode|
            vnode.status = Resource::Status::RUNNING
          }
        }

        if async
          thr = Thread.new {
            block.call
          }
          thr.abort_on_exception = true
        else
          block.call
        end

        return vnodes
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
        return @daemon_resources.vnodes
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
          downkeys(desc)
          vnode.add_viface(viface)
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
        @daemon_resources_lock.synchronize {
          vnode.host.local_vifaces -= 1 if vnode.host
        }
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

          raise Lib::MissingParameterError, "address|vnetwork" if \
          ((!desc['address'] or desc['address'].empty?) \
           and (!desc['vnetwork'] or desc['vnetwork'].empty?))

          vplatform = @daemon_resources

          address = ''
          if desc['address'] and !desc['address'].empty?
            begin
              address = IPAddress.parse(desc['address'])
            rescue ArgumentError
              raise Lib::InvalidParameterError, desc['address']
            end
            prop = desc['address']
            vnetwork = vplatform.get_vnetwork_by_address(prop)
          end

          if (!desc.has_key?('macaddress')) || (desc['macaddress'] == nil) || (desc['macaddress'] == '')
            @@mac_id_lock.synchronize {
              mac_suffix = [@@mac_id/65536, @@mac_id%65536/256, @@mac_id%65536%256].map {|i| i.to_s(16).rjust(2,"0")}.join(":")
              viface.macaddress = "#{MAC_PREFIX}:#{mac_suffix}"
              @@mac_id += 1
            }
          else
            if desc['macaddress'].match(/^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/)
              viface.macaddress = desc['macaddress']
            else
              raise Lib::InvalidParameterError, desc['macaddress']
            end
          end
          if desc['vnetwork'] and !desc['vnetwork'].empty?
            prop = desc['vnetwork']
            vnetwork = vplatform.get_vnetwork_by_name(prop)
          end
          viface.bridge = (vnetwork.vxlan_id > 0) ? Lib::NetTools::VXLAN_BRIDGE_PREFIX + vnetwork.vxlan_id.to_s : Lib::NetTools::DEFAULT_BRIDGE
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
          cl = NetAPI::Client.new(vnode.host.address, 4568)
          cl.vinput_update(vnode.name,viface.name,desc)
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
          cl = NetAPI::Client.new(vnode.host.address, 4568)
          cl.voutput_update(vnode.name,viface.name,desc)
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
          val = nil
          unit = 'mhz'

          if desc['vcores']
            raise Lib::InvalidParameterError, 'vcores' unless desc['vcores'].is_a?(Array)
            val = desc['vcores'][0]['frequency']
            corenb = desc['vcores'].size
          else
            if desc['val']
              val = desc['val']
              unit = desc['unit'] if desc.has_key?('unit')
            else
              val = 1
              unit = 'ratio'
            end
            corenb = desc['corenb'].to_i || 1
          end

          vnode.add_vcpu(corenb,val,unit)

          vnode.vcpu.attach if vnode.host

          if vnode.status == Resource::Status::RUNNING
            vnode.status = Resource::Status::CONFIGURING
            cl = NetAPI::Client.new(vnode.host.address, 4568)
            cl.vcpu_update(vnode.name,val,unit)
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

      def vcpu_update(vnodename,desc)
        begin
          vnode = vnode_get(vnodename)
          raise Lib::UninitializedResourceError, 'vcpu' unless vnode.vcpu
          vcpu = vnode.vcpu
          downkeys(desc)

          val = nil
          unit = 'mhz'
          if desc['vcores']
            raise Lib::InvalidParameterError, 'vcores' unless desc['vcores'].is_a?(Array)
            val = desc['vcores'][0]['frequency']
          else
            if desc['val']
              val = desc['val']
              unit = desc['unit'] if desc.has_key?('unit')
            else
              val = 1
              unit = 'ratio'
            end
          end

          vcpu.update_vcores(val,unit)

          if vnode.status == Resource::Status::RUNNING
            vnode.status = Resource::Status::CONFIGURING
            cl = NetAPI::Client.new(vnode.host.address, 4568)
            cl.vcpu_update(vnode.name,val,unit)
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
        if desc.has_key?('disk_throttling') && desc['disk_throttling']
          desc['disk_throttling'].each_key { |k|
            raise Lib::InvalidParameterError, "filesystem/disk_throttling/#{k}" if !['device','read_limit', 'write_limit'].include?(k)
          }
          raise Lib::MissingParameterError, "filesystem/disk_throttling/device" if (desc['disk_throttling'].has_key?('read_limit') || desc['disk_throttling'].has_key?('write_limit')) && !desc['disk_throttling'].has_key?('device')
        else
          desc['disk_throttling'] = nil
        end
        vnode.filesystem = Resource::FileSystem.new(vnode,desc['image'],desc['shared'],desc['cow'],desc['disk_throttling'])
        return vnode.filesystem
      end

      def vfilesystem_update(vnodename,desc)
        vnode = vnode_get(vnodename)
        raise Lib::UninitializedResourceError, "filesystem" unless \
        vnode.filesystem
        vnode.filesystem.image = URI.encode(desc['image']) if desc['image']
        vnode.filesystem.shared = parse_bool(desc['shared']) if desc['shared']
        vnode.filesystem.cow = parse_bool(desc['cow']) if desc['cow']
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

      # Execute and get the result of a command on a virtual node
      # ==== Attributes
      # * +command+ the command to be executed
      # ==== Returns
      # Hash object: { 'command' => <the command that was executed>, 'result' => <the result of the command> }
      # ==== Exceptions
      #
      def vnode_execute(vnodename,command)
        ret = ""
        # >>> TODO: check if vnode exists
        vnode = vnode_get(vnodename)
        raise unless vnode
        raise Lib::UninitializedResourceError, vnode.name unless \
        vnode.status == Resource::Status::RUNNING
        ret = Daemon::Admin.vnode_run(vnode,command)

        return ret
      end

      def vnetwork_sync(vnet, pnode, lock=true)
        block = Proc.new do
          if !vnet.visibility.include?(pnode)
            vnet.visibility << pnode
            cl = NetAPI::Client.new(pnode.address.to_s, 4568)
            # Adding VNetwork on the pnode
            cl.vnetwork_create(vnet.name,vnet.address.to_string,{'nb_pnodes' => @daemon_resources.pnodes.length, 'pnode_index' => @daemon_resources.pnodes.keys.index(pnode.address.to_s), 'vxlan_id' => vnet.vxlan_id.to_i, 'root_iface' => @@root_iface})

            # Adding VRoutes to the new VNetwork
            vnet.vroutes.values.each do |vroute|
              vnetwork_sync(vroute.dstnet,pnode,false)
              cl.vroute_create(vnet.name,vroute.dstnet.name,vroute.gw.to_s)
            end
          end
        end

        if lock
          @@lockslock.synchronize {
            @@locks[:vnetsync][pnode] = Mutex.new unless \
            @@locks[:vnetsync][pnode]
          }

          @@locks[:vnetsync][pnode].synchronize do
            block.call
          end
        else
          block.call
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
      def vnetwork_create(name,address,opts=nil)
        begin
          if name
            name = name.gsub(' ','_')
          else
            name = "vnetwork#{@vnet_id}"
            @vnet_id += 1
          end
          if @@network_mode == 'vxlan'
            vnetwork = Resource::VNetwork.new(address,name,@daemon_resources.pnodes.length,@@vxlan_id)
            @@vxlan_id_lock.synchronize {
              @@vxlan_id += 1
            }
          else
            vnetwork = Resource::VNetwork.new(address,name,@daemon_resources.pnodes.length,0)
          end
          @daemon_resources.add_vnetwork(vnetwork)

          if @@network_mode == 'classical'
            pnodes = @daemon_resources.pnodes.values
            mask = vnetwork.address.netmask
            #Add a virtual interface connected in the network on every Pnode
            w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
            pnodes.each_index { |i|
              block = Proc.new {
                cl = NetAPI::Client.new(pnodes[i].address.to_s, 4568)
                cl.vnetwork_create_routing_interface(IPAddress::IPv4::parse_u32(vnetwork.address.last.to_u32 - i).to_s, mask)
              }
              w.add(block)
            }
            w.run
          end
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
        @daemon_resources.remove_vnetwork(vnetwork)
        vnetwork.visibility.each do |pnode|
          if (pnode.status == Resource::Status::RUNNING)
            cl = NetAPI::Client.new(pnode.address.to_s, 4568)
            cl.vnetwork_remove(vnetwork.name)
          end
        end
        return vnetwork
      end

      # Delete every virtual networks
      # ==== Returns
      # Array of Resource::VNetwork objects
      # ==== Exceptions
      #
      def vnetworks_remove()
        vnetworks = @daemon_resources.vnetworks
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
        vnetwork = @daemon_resources.get_vnetwork_by_name(name)
        raise Lib::ResourceNotFoundError, name if raising and !vnetwork
        return vnetwork
      end

      # Get the list of the the currently created virtual networks
      # ==== Returns
      # Array of Resource::VNetwork objects
      # ==== Exceptions
      #
      def vnetworks_get()
        return @daemon_resources.vnetworks
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
          raise Lib::ResourceNotFoundError, networksrc unless srcnet
          destnet = vnetwork_get(networkdst)
          raise Lib::ResourceNotFoundError, networkdst unless destnet
          found = false
          if IPAddress.valid?(nodegw)
            @daemon_resources.vnodes.each_value { |vnode|
              vnode.vifaces.each { |viface|
                if viface.address.address == nodegw
                  nodegw = vnode.name
                  found = true
                  break
                end
              }
              break if found
            }
          end
          gw = vnode_get(nodegw)
          raise Lib::ResourceNotFoundError, nodegw unless gw
          gwaddr = gw.get_viface_by_network(srcnet)
          gwaddr = gwaddr.address if gwaddr
          raise Lib::InvalidParameterError, nodegw unless gwaddr
          vroute = srcnet.get_vroute(destnet)
          unless vroute
            vroute = Resource::VRoute.new(srcnet,destnet,gwaddr)
            srcnet.add_vroute(vroute)
          end
          raise Lib::InvalidParameterError, "#{gw.name}->#{srcnet}" unless gw.connected_to?(srcnet)
          vnode_mode_update(gw.name,Resource::VNode::MODE_GATEWAY) unless gw.gateway
          srcnet.visibility.each do |pnode|
            if (pnode.status == Resource::Status::RUNNING)
              cl = NetAPI::Client.new(pnode.address.to_s, 4568)
              vnetwork_sync(destnet,pnode)
              cl.vroute_create(srcnet.name,destnet.name,gwaddr.to_s)
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

      # Add an event trace to a resource
      def event_trace_add(resource_desc, event_type, trace)
        trace.to_a.each do |date, event_value|
          @event_trace.add_event(date.to_f, Events::Event.new(resource_desc, event_type, event_value))
        end
      end

      # Add an event trace to a resource, from a string
      def event_trace_string_add(resource_desc, event_type, trace)
        trace.strip.split(/\n+/).each do |trace_line|
          date, event_value = trace_line.split
          @event_trace.add_event(date.to_f, Events::Event.new(resource_desc, event_type, event_value))
        end
      end

      # Add an random generated event to a resource
      def event_random_add(resource_desc, event_type, generator_desc, first_value = nil)
        event = Events::EventGenerator.new(resource_desc, event_type, generator_desc, first_value)
        @event_trace.add_event(event.get_next_date, event)
      end

      # Start the churn
      def event_manager_start
        @event_manager.run
      end

      # Stop the churn
      def event_manager_stop
        @event_manager.stop
      end

      # Load a configuration
      # ==== Attributes
      # * +data+ data to be applied
      # * +format+ the format of the data
      # * +rootfs+ the rootfs to boot vnodes
      # ==== Returns
      # Resource::VPlatform object
      # ==== Exceptions
      #
      def vplatform_create(format,data,rootfs=nil)
        # >>> TODO: check if there is already a created vplatform
        raise Lib::MissingParameterError, 'data' unless data
        parser = nil
        desc = {}
        case format.upcase
        when 'JSON'
          desc = JSON.parse(data)
        when 'SIMGRID'
          raise Lib::MissingParameterError, 'rootfs' unless rootfs
          parser = TopologyStore::SimgridReader.new(rootfs)
          desc = parser.parse(data)
        else
          raise Lib::InvalidParameterError, format
        end
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
            vnode_create([vnodedesc['name']], vnodedesc).first
          end
        end
        # Creating VRoutes
        #vroute_complete()
        if desc['vplatform']['vnetworks']
          desc['vplatform']['vnetworks'].each do |vnetdesc|
            if vnetdesc['vroutes']
              vnetdesc['vroutes'].each do |vroutedesc|
                vroute_create(vroutedesc['networksrc'],vroutedesc['networkdst'],
                              vroutedesc['gateway'])
              end
            end
          end
        end
        return @daemon_resources
      end

      # Get the description file of the current platform in a specified format (JSON if not specified)
      # ==== Returns
      # String value that reprents the platform in the _format_ form
      # ==== Exceptions
      #
      def vplatform_get()
        visitor = TopologyStore::HashWriter.new
        h = visitor.visit(@daemon_resources)
        if h["vplatform"]["vnodes"] && !h["vplatform"]["vnodes"].empty?
          h["vplatform"]["vnodes"].each { |vnode|
            if vnode["vfilesystem"]["image"]
              vnode["vfilesystem"]["image"] = CGI.unescape(vnode["vfilesystem"]["image"])
            end
          }
        end
        return JSON.pretty_generate(h)
      end

      def set_peers_latencies(vnodes, matrix)
        #sanity check
        if (vnodes.length == matrix.length)
          matrix.each { |row|
            if row.length != vnodes.length
              return false
            end
          }
        else
          return false
        end
        vnodesbyhost = {}
        #group vnodes by pnode
        vnodes.each { |name|
          vnode = vnode_get(name)
          vnode.status = Resource::Status::CONFIGURING
          host = vnode.host.address
          vnodesbyhost[host] = {} if !vnodesbyhost.has_key?(host)
          vnodesbyhost[host][vnode.name] = {}
          row = matrix[vnodes.index(name)]
          rules = {}
          (0...matrix.length).each { |i|
            if row[i] != 0
              dest_vnode = vnode_get(vnodes[i])
              rules[dest_vnode.vifaces[0].address.to_s] = row[i]
            end
          }
          vnodesbyhost[host][vnode.name] = vnode.vifaces[0].latency_filters = rules
        }
        tids = []
        vnodesbyhost.each_pair { |pnode,vnodeshash|
          tids << Thread.new {
            cl = NetAPI::Client.new(pnode, 4568)
            cl.set_peers_latencies(nil, vnodeshash)
          }
        }
        tids.each { |tid| tid.join }
        vnodes.each { |name|
          vnode = vnode_get(name)
          vnode.status = Resource::Status::RUNNING
        }
        return true
      end

      def set_global_etchosts(param = nil)
        results = []
        @daemon_resources.vnodes.each_value {|vnode|
          vnode.vifaces.each do |viface|
            if viface.vnetwork
              results << viface.address.address.to_s + " " + vnode.name
            end
          end
        }
        data = Base64.encode64(Zlib::Deflate.deflate(results.join("\n")))
        w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
        @daemon_resources.pnodes.each_value {|pnode|
          block = Proc.new {
            cl = NetAPI::Client.new(pnode.address.to_s, 4568)
            cl.set_global_etchosts(data)
          }
          w.add(block)
        }
        w.run
      end

      def vmem_create(vnodename, opts)
        vnode = vnode_get(vnodename)
        vnode.add_vmem(opts)
        return opts
      end

      def set_global_arptable(param = nil, arp_file = nil)
        results = []
        @daemon_resources.vnodes.each_value {|vnode|
          vnode.vifaces.each {|viface|
            if viface.vnetwork
              results << viface.macaddress + " " + viface.address.address.to_s
            end
          }
        }
        data = Base64.encode64(Zlib::Deflate.deflate(results.join("\n")))
        arp_file = '/tmp/fullarptable'
        w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
        @daemon_resources.pnodes.each_value {|pnode|
          block = Proc.new {
            cl = NetAPI::Client.new(pnode.address.to_s, 4568)
            cl.set_global_arptable(data, arp_file)
          }
          w.add(block)
        }
        w.run
      end

      def wait_vnodes(opts)
        vnodes = nil
        timeout = 600
        port = 22
        if opts
          if opts.has_key?('vnodes') && (opts['vnodes'] != nil)
            vnodes = opts['vnodes'].is_a?(Array) ? opts['vnodes'] : [ opts['vnodes'] ]
          end
          if opts.has_key?('timeout') && (opts['timeout'] != nil)
            timeout = opts['timeout']
          end
          if opts.has_key?('port') && (opts['port'] != nil)
            port = opts['port']
          end
        end

        vnodesbyhost = nil
        #group vnodes by pnode
        if vnodes
          vnodesbyhost = {}
          vnodes.each { |name|
            vnode = vnode_get(name)
            host = vnode.host.address.to_s
            vnodesbyhost[host] = [] if !vnodesbyhost.has_key?(host)
            vnodesbyhost[host] << vnode.name
          }
        end

        w = Distem::Lib::Synchronization::SlidingWindow.new(WINDOW_SIZE)
        ret = {}
        if vnodesbyhost
          vnodesbyhost.each_pair { |pnodeaddress,vn|
            block = Proc.new {
              cl = NetAPI::Client.new(pnodeaddress, 4568)
              ret[pnodeaddress] = cl.wait_vnodes({'port' => port, 'vnodes' => vn, 'timeout' => timeout})
            }
            w.add(block)
          }
        else
          @daemon_resources.pnodes.each_value {|pnode|
            block = Proc.new {
              cl = NetAPI::Client.new(pnode.address.to_s, 4568)
              ret[pnode.address.to_s] = cl.wait_vnodes({'port' => port, 'vnodes' => nil, 'timeout' => timeout})
            }
            w.add(block)
          }
        end
        w.run

        return ret.values.include?(false) ? ['false'] : ['true']
      end

      protected

      # Get a new version of the hash with downcase keys
      # ==== Attributes
      # * +hash+ The Hash object
      # ==== Returns
      # New Hash object
      def downkeys(hash)
        if hash.is_a?(Hash)
          hash.dup.each do |k,v|
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

        # Commented since the coordinator view of the VCpu should not be modified by the Pnode view
        # if vnode.vcpu
        #   #vnode.vcpu.pcpu = vnode.host.cpu if vnode.host
        #   i = 0
        #   vnode.vcpu.vcores.each_value do |vcore|
        #     vcore.pcore = hash['vcpu']['vcores'][i]['pcore']
        #     vcore.frequency = hash['vcpu']['vcores'][i]['frequency'].split[0].to_i * 1000
        #     i += 1
        #   end
        # end
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
        @daemon_resources.destroy(resource)
      end
    end
  end
end
