#require 'distem'

module Distem
  module Node

    # Class that help to set up a physical node resource specifying virtual ones
    class ConfigManager
      # The virtual platform that describes all virtual resources set on this physical node
      attr_reader  :vplatform
      # The physical node to work on
      attr_accessor :pnode

      # Create a new ConfigManager object
      def initialize
        @pnode = Distem::Resource::PNode.new(Lib::NetTools.get_default_addr())
        @vplatform = Distem::Resource::VPlatform.new
        @containers = {}
        Container.clean()
      end

      # Gets a virtual node object specifying it's name
      # ==== Attributes
      # * +name+ The name (String)
      # ==== Returns
      # VNode object or nil if not found
      #
      def get_vnode(name)
        return @vplatform.get_vnode(name)
      end

      # Gets the Container object associated to a virtual node
      # ==== Attributes
      # * +name+ The name of the virtual node (String)
      # ==== Returns
      # Container object or nil if not found
      #
      def get_container(name)
        return (@containers.has_key?(name) ? @containers[name] : nil)
      end

      # Add a virtual node and initialize all the resources it will use on the physical node (uncompress it's filesystem, create it's container (cgroups,lxc, ...), ...)
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def vnode_add(vnode)
        # >>> TODO: Add the ability to modify a VNode
        @vplatform.add_vnode(vnode)
      end

      # Remove a virtual node and clean all it's associated resources on the physical node (remove it's filesystem files, remove it's container (cgroups,lxc, ...), ...)
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def vnode_remove(vnode)
        raise unless vnode.is_a?(Resource::VNode)
        if @containers[vnode.name] 
          @containers[vnode.name].destroy
          @containers.delete(vnode.name)
        end
        @vplatform.remove_vnode(vnode)
      end

      #def vnode_configure(vnodename)
      #  vnode = @vplatform.get_vnode(vnodename)
      #  raise Lib::ResourceNotFoundError, vnodename unless vnode
      #  @containers[vnodename].configure()
      #end

      # Start a virtual node to be able to use it (it have to be installed and in the status READY)
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def vnode_start(vnode)
        if @containers[vnode.name]
          @containers[vnode.name].start()
        else
          @containers[vnode.name] = Node::Container.new(vnode)
          @containers[vnode.name].configure()
          @containers[vnode.name].start()
=begin
          vnode.vifaces.each do |viface|
            if viface.vtraffic? and !viface.limited?
              viface_configure(viface)
            end
          end
=end
        end
      end

      # Reconfigure a virtual node (apply changes to the abstract virtual resources to the physical node settings)
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def vnode_reconfigure(vnode)
        raise Lib::ResourceNotFoundError, vnode unless vnode

        @containers[vnode.name].reconfigure()
      end

      # Update a virtual node (apply/undo changes to the abstract virtual resources to the physical node settings)
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def vnode_update(vnode)
        raise Lib::ResourceNotFoundError, vnode unless vnode

        @containers[vnode.name].update()
      end

      # Stop a virtual node (it have to be started and in the status RUNNING)
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def vnode_stop(vnode)
        if @containers[vnode.name]
          @containers[vnode.name].stop()
        end
      end

      def vnode_freeze(vnode)
        if @containers[vnode.name]
          @containers[vnode.name].freeze
        end
      end

      def vnode_unfreeze(vnode)
        if @containers[vnode.name]
          @containers[vnode.name].unfreeze
        end
      end

      # Remove a virtual network interface (deprecated)
      # ==== Attributes
      # * +viface+ The VIface object
      #
      #def viface_remove(viface)
      #  viface.detach()
      #end

      # Add a virtual network
      # ==== Attributes
      # * +vnetwork+ The VNetwork object
      #
      def vnetwork_add(vnetwork)
        @vplatform.add_vnetwork(vnetwork)
      end

      # Remove a virtual network
      # ==== Attributes
      # * +vnetwork+ The VNetwork object
      #
      def vnetwork_remove(vnetwork)
        #vnodes = vnetwork.vnodes.clone
        @vplatform.remove_vnetwork(vnetwork)
        #vnodes.each_pair do |vnode,viface|
        #  vnode_configure(vnode)
        #end
      end

      # Remove a virtual route
      # ==== Attributes
      # * +vroute+ The VRoute object
      #
      def vroute_remove(vroute)
        @vplatform.remove_vroute(vroute)
      end

      # Remove a virtual resource (use it's _remove associated method)
      # ==== Attributes
      # * +resouce+ The Resource object (have to be of class VNode, VNetwork or VRoute)
      #
      def destroy(resource)
        if resource.is_a?(Resource::VNode)
          vnode_remove(resource)
        elsif resource.is_a?(Resource::VNetwork)
          vnetwork_remove(resource)
        elsif resource.is_a?(Resource::VRoute)
          vroute_remove(resource)
        end
      end

      def set_global_etchosts(vnode, data)
        @containers[vnode.name].set_global_etchosts(data)
      end

      def set_global_arptable(vnode, data, file)
        @containers[vnode.name].set_global_arptable(data, file)
      end
    end

  end
end
