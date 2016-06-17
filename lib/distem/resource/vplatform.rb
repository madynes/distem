require 'resolv'

module Distem
  module Resource

    # Abstract representation of a virtual platform resource that's describing an experimental environment (PNodes,VNodes,VNetworks,...)
    class VPlatform
      # Hash of the physical nodes associated to this virtual platform (key: PNode.address, val: PNode)
      attr_reader :pnodes
      # Hash of the virtual nodes associated to this virtual platform (key: VNode.name, val: VNode)
      attr_reader  :vnodes
      # Hash of the virtual networks associated to this virtual platform (key: VNetwork.name, val: VNetwork)
      attr_reader  :vnetworks

      # Create a new VPlatform
      def initialize
        @pnodes = {}
        @vnodes = {}
        @vnetworks = {}
      end

      # Add a new physical node to the platform
      # ==== Attributes
      # * +pnode+ The PNode object
      #
      def add_pnode(pnode)
        raise unless pnode.is_a?(PNode)
        raise Lib::AlreadyExistingResourceError, pnode.address.to_s \
          if @pnodes[pnode.address]

        @pnodes[pnode.address] = pnode
      end

      # Remove physical node from the platform
      # ==== Attributes
      # * +pnode+ The PNode object
      #
      def remove_pnode(pnode)
        raise unless pnode.is_a?(PNode)
        @pnodes.delete(pnode.address)
      end

      # Get a physical node specifying it's address
      # ==== Attributes
      # * +address+ The IP address (String)
      # ==== Returns
      # PNode object or nil if not found
      # ==== Exceptions
      # * +ResolvError+ if the address don't have a valid format
      #
      def get_pnode_by_address(address)
        # >>> TODO: validate ip address
        ret = nil
        begin
          ret = @pnodes[Resolv.getaddress(address)]
        rescue Resolv::ResolvError
          ret = nil
        ensure
          return ret
        end
      end

      # Get a physical node specifying the name of a virtual node which it's connected on it
      # ==== Attributes
      # * +name+ The name of the VNode (String)
      # ==== Returns
      # PNode object or nil if not found
      #
      def get_pnode_by_name(name)
        return (@vnodes[name] ? @vnodes[name].host : nil)
      end

      # Gets a physical node which is available to host a virtual node considering VCPU and VNetwork constraints
      # ==== Attributes
      # * +vnode+ The virtual node
      # ==== Returns
      # PNode object or nil if not found
      # ==== Exceptions
      # * +UnavailableResourceError+ if no physical nodes are available (no PNode in this VPlatform)
      #
      def get_pnode_available(vnode)
        availables = []
        # Might lead to race condition, must be executed inside a critical section
        @pnodes.each_value do |pnode|
          next if (vnode.vcpu && pnode.cpu.get_free_cores.size < vnode.vcpu.vcores.size) ||
            ((pnode.local_vifaces + vnode.vifaces.length) > Node::Admin.vifaces_max) ||
            (vnode.vmem && ((vnode.vmem.mem && (pnode.memory.get_free_capacity < vnode.vmem.mem)) &&
                             (vnode.vmem.swap && (pnode.memory.get_free_swap < vnode.vmem.swap))))
          availables << pnode
        end
        raise Lib::UnavailableResourceError, 'pnode/cpu, pnode/iface, or pnode/memory' if availables.empty?
        pnode = availables[rand(availables.size)]
        pnode.local_vifaces += vnode.vifaces.length
        return pnode
      end

      # Add a new virtual node to the platform
      # ==== Attributes
      # * +vnode+ The VNode object
      # ==== Exceptions
      # * +AlreadyExistingResourceError+ if a virtual node with the same name already exists
      #
      def add_vnode(vnode)
        raise unless vnode.is_a?(VNode)
        raise Lib::AlreadyExistingResourceError, vnode.name \
          if @vnodes[vnode.name]

        @vnodes[vnode.name] = vnode
      end

      # Remove a virtual node from the platform. If the virtual node is acting as gateway in some virtual routes, also remove this vroutes from the platform.
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def remove_vnode(vnode)
        raise unless vnode.is_a?(VNode)
        # Remove the vnode on each vnetwork it's connected
        @vnetworks.each_value do |vnetwork|
          if vnetwork.vnodes.keys.include?(vnode)
            # Remove every vroute vnode have a role on
            vnetwork.vroutes.each_value do |vroute|
                viface = vnetwork.get_vnode_viface(vnode)
                if viface and viface.address.to_s == vroute.gw.to_s
                  vnetwork.remove_vroute(vroute)
                end
            end
            vnetwork.remove_vnode(vnode)
          end
        end
        @vnodes.delete(vnode.name)
      end

      # Get a virtual node specifying it's name
      # ==== Attributes
      # * +name+ The name (String)
      # ==== Returns
      # VNode object or nil if not found
      #
      def get_vnode(name)
        return (@vnodes.has_key?(name) ? @vnodes[name] : nil)
      end

      # Add a new virtual network to the platform
      # ==== Attributes
      # * +vnetwork+ The VNetwork object
      # ==== Exceptions
      # * +AlreadyExistingResourceError+ if a virtual network with the same name or the same address range already exists
      #
      def add_vnetwork(vnetwork)
        raise unless vnetwork.is_a?(VNetwork)
        raise Lib::AlreadyExistingResourceError, "#{vnetwork.address.to_string}(#{vnetwork.name})" \
          if @vnetworks[vnetwork.name]

        @vnetworks[vnetwork.name] = vnetwork
      end

      # Remove a virtual network from the platform. Also remove all virtual routes this virtual network is playing a role in.
      # ==== Attributes
      # * +vnetwork+ The VNetwork object
      #
      def remove_vnetwork(vnetwork)
        raise unless vnetwork.is_a?(VNetwork)
        # Remove all associated vroutes
        @vnetworks.each_value do |vnet|
          next if vnet == vnetwork
          vnet.vroutes.each_value do |vroute|
            vnet.remove_vroute(vroute) if vroute.dstnet == vnetwork
          end
        end
        vnetwork.destroy()
        @vnetworks.delete(vnetwork.name)
      end

      # Get a virtual network specifying it's name
      # ==== Attributes
      # * +name+ The name (String)
      # ==== Returns
      # VNetwork object or nil if not found
      #
      def get_vnetwork_by_name(name)
        return @vnetworks[name]
      end

      # Get a virtual network specifying an IP address it's address range is including
      # ==== Attributes
      # * +address+ The address (String or IPAddress)
      # ==== Returns
      # VNetwork object or nil if not found
      #
      def get_vnetwork_by_address(address)
        raise unless (address.is_a?(String) or address.is_a?(IPAddress))
        raise if address.empty?
        ret = nil
        begin
          address = IPAddress.parse(address) if address.is_a?(String)
          address = address.network
        rescue ArgumentError
          return nil
        end

        ret = @vnetworks.values.select{ |vnet| vnet.address.include?(address) }[0]
        return ret
      end

      # Add a new virtual network route to the platform
      # ==== Attributes
      # * +vroute+ The VRoute object
      # ==== Exceptions
      # * +ResourceNotFoundError+ if the source virtual network (VRoute.srcnet) is not found on the platform
      #
      def add_vroute(vroute)
        raise unless vroute.is_a?(VRoute)
        vnetwork = @vnetworks[vroute.srcnet.name]
        raise Lib::ResourceNotFoundError, vroute.srcnet.name unless vnetwork
        vnetwork.add_vroute(vroute)
      end

      # Remove a virtual network route from the platform
      # ==== Attributes
      # * +vroute+ The VRoute object
      # ==== Exceptions
      # * +ResourceNotFoundError+ if the source virtual network (VRoute.srcnet) is not found on the platform
      #
      def remove_vroute(vroute)
        raise unless vroute.is_a?(VRoute)
        vnetwork = @vnetworks[vroute.srcnet.name]
        raise Lib::ResourceNotFoundError, vroute.srcnet.name unless vnetwork
        vnetwork.remove_vroute(vroute)
      end

      # Creates a dot file with the contents of the vnodes
      def vnodes_to_dot(output_file)

        visitor = TopologyStore::HashWriter.new
        vnodes = visitor.visit(@vnodes)

        graph_g = GraphViz.graph( "G" ) do |graph_g|
          vs = graph_g.add_nodes("vs", :cpu =>0, :type => "switch")
          vnodes.each do |n,vnode|
            vcores = vnode["vcpu"].nil?? 0 : vnode["vcpu"]["vcores"].length
            # Bandwidth units are set to bps
            bandwidth = vnode["vifaces"].inject(0){ |sum, b| sum + to_mps(b["output"]["bandwidth"]["rate"])}
            gnode = graph_g.add_nodes( n,:cpu => vcores,:type => "host")
            graph_g.add_edges( gnode, vs, :bandwidth => bandwidth)
          end

        end
        graph_g.output(:none => output_file)
        return true
      end

      def load_physical_topo(physical_topo)
        map_distem_physical_topo = {}
        raise "Physical topology file #{physical_topo} not found" unless File.exist?(physical_topo)
        p_topo = GraphViz.parse(physical_topo)
        raise Lib::ParameterError, "Impossible to load topology file, probably a problem with DOT syntax" if p_topo.nil?
        p_topo.each_node do |node_name, node|
          node.each_attribute{ |attr_name,value|
            # There are escaped characters returned by graphviz
            map_distem_physical_topo[node_name] = value.to_s.delete('\\"') if attr_name =="ip"
          }
        end
        return map_distem_physical_topo
      end
      # Delete a resource from the virtual platform
      # ==== Attributes
      # * +resource+ The resource object (have to be of class: PNode,VNode,VNetwork or VRoute)
      #
      def destroy(resource)
        if resource.is_a?(PNode)
          remove_pnode(resource)
        elsif resource.is_a?(VNode)
          remove_vnode(resource)
        elsif resource.is_a?(VNetwork)
          remove_vnetwork(resource)
        elsif resource.is_a?(VRoute)
          remove_vroute(resource)
        end
      end

      def to_mps(rate)
        rates_def = {"bps"=>1, "kbps"=>1000, "mbps"=>1000000, "bgps"=>1000000000}
        conversion = rates_def.keys.select{ |k| rate.include?(k)}.pop
        real_value = rates_def[conversion]*rate.split(conversion).pop.to_i
        return real_value
      end

    end

  end
end
