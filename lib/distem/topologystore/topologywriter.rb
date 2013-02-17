#require 'distem'

module Distem
  module TopologyStore

    # Base interface for the saving methods. Based on the Visitor design pattern.
    class TopologyWriter < StoreBase
      def method_missing(method, *args)
        raise args[0].class.name
      end

      # Visit a resource object, automatically call the right method.
      # ==== Attributes
      # * +object+ The Resource object
      # ==== Returns
      # Object value of the kind of the concrete class (i.e. HashWriter returns an Hash object)
      def visit( object )
        self.send( "visit_#{object.class.name.split('::').last.downcase}".to_sym, object )
      end

      # Visit a virtual platform object. All the other "visit_" methods are working the same way.
      # ==== Attributes
      # *+vplatform+ The VPlatform object
      # ==== Returns
      # Object value of the kind of the concrete class (i.e. HashWriter returns an Hash object)
      #
      def visit_vplatform(vplatform)
        raise unless vplatform.is_a?(Resource::VPlatform)
      end

      def visit_pnode(pnode) # :nodoc:
        raise unless pnode.is_a?(Resource::PNode)
      end

      def visit_vnode(vnode) # :nodoc:
        raise unless vnode.is_a?(Resource::VNode)
      end

      def visit_viface(viface) # :nodoc:
        raise unless viface.is_a?(Resource::VIface)
      end

      def visit_filesystem(filesystem) # :nodoc:
        raise unless filesystem.is_a?(Resource::FileSystem)
      end

      def visit_vnetwork(vnetwork) # :nodoc:
        raise unless vnetwork.is_a?(Resource::VNetwork)
      end

      def visit_vroute(vroute) # :nodoc:
        raise unless vroute.is_a?(Resource::VRoute)
      end

      def visit_vtraffic(vtraffic) # :nodoc:
        raise unless vtraffic.is_a?(Resource::VIface::VTraffic)
      end

      def visit_bandwidth(limitbw) # :nodoc:
        raise unless limitbw.is_a?(Resource::Bandwidth)
      end

      def visit_latency(limitlat) # :nodoc:
        raise unless limitlat.is_a?(Resource::Latency)
      end

      def visit_nilclass(obj) # :nodoc:
        return nil
      end
      #
      # Visit a String object
      # ==== Attributes
      # * +str+ The String object
      # ==== Returns
      # Object value of the kind of the concrete class (i.e. HashWriter returns an Hash object)
      def visit_string(str)
        return str
      end


      # Visit an Hash object, call the "visit" method for each *values* in the Hash.
      # ==== Attributes
      # * +hash+ The Hash object
      # ==== Returns
      # Object value of the kind of the concrete class (i.e. HashWriter returns an Hash object)
      def visit_hash(hash)
        ret = hash.values.collect { |val| visit(val) }
        return ret
      end

      # Visit an Array object, call the "visit" method for each values in the Hash.
      # ==== Attributes
      # * +array+ The Array object
      # ==== Returns
      # Object value of the kind of the concrete class (i.e. HashWriter returns an Hash object)
      def visit_array(array)
        ret = array.collect { |val| visit(val) }
        return ret
      end
    end

  end
end
