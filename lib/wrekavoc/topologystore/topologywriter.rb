require 'wrekavoc'

module Wrekavoc
  module TopologyStore

    class TopologyWriter < StoreBase
      def method_missing(method, *args)
        raise args[0].class.name
      end

      def visit( object )
        self.send( "visit_#{object.class.name.split('::').last.downcase}".to_sym, object )
      end

      def visit_vplatform(vplatform)
        raise unless vplatform.is_a?(Resource::VPlatform)
      end

      def visit_pnode(pnode)
        raise unless pnode.is_a?(Resource::PNode)
      end

      def visit_vnode(vnode)
        raise unless vnode.is_a?(Resource::VNode)
      end

      def visit_viface(viface)
        raise unless viface.is_a?(Resource::VIface)
      end

      def visit_filesystem(filesystem)
        raise unless filesystem.is_a?(Resource::FileSystem)
      end

      def visit_vnetwork(vnetwork)
        raise unless vnetwork.is_a?(Resource::VNetwork)
      end

      def visit_vroute(vroute)
        raise unless vroute.is_a?(Resource::VRoute)
      end

      def visit_vtraffic(vtraffic)
        raise unless vtraffic.is_a?(Resource::VIface::VTraffic)
      end

      def visit_bandwidth(limitbw)
        raise unless limitbw.is_a?(Resource::Bandwidth)
      end

      def visit_latency(limitlat)
        raise unless limitlat.is_a?(Resource::Latency)
      end

      def visit_nilclass(obj)
        return nil
      end

      def visit_hash(hash)
        ret = hash.values.collect { |val| visit(val) }
        return ret
      end

      def visit_array(array)
        ret = array.collect { |val| visit(val) }
        return ret
      end
    end

  end
end