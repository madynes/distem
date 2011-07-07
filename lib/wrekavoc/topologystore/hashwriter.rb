require 'wrekavoc'

module Wrekavoc
  module TopologyStore

    class HashWriter < TopologyWriter
      def visit_vplatform(vplatform)
        return {
          'pnodes' => visit(vplatform.pnodes),
          'vnodes' => visit(vplatform.vnodes),
          'vnetworks' => visit(vplatform.vnetworks),
        }
      end

      def visit_pnode(pnode)
        return {
          'id' => pnode.id.to_s,
          'address' => pnode.address,
          'status' => pnode.status,
        }
      end

      def visit_vnode(vnode)
        return {
          'id' => vnode.id.to_s,
          'name' => vnode.name,
          'host' => vnode.host.address.to_s,
          'filesystem' => visit(vnode.filesystem),
          'status' => vnode.status,
          'gateway' => vnode.gateway.to_s,
          'ifaces' => visit(vnode.vifaces),
        }
      end

      def visit_viface(viface)
        return {
          'id' => viface.id.to_s,
          'name' => viface.name,
          'vnode' => viface.vnode.name,
          'address' => viface.address.to_string,
          'connected_to' => (viface.vnetwork ? viface.vnetwork.name : 'nil'),
          'limit_input' => (viface.limit_input ? visit(viface.limit_input) : 'nil'),
          'limit_output' => (viface.limit_output ? visit(viface.limit_output) : 'nil'),
        }
      end

      def visit_filesystem(filesystem)
        return {
          'vnode' => filesystem.vnode,
          'image' => filesystem.image,
          'path' => filesystem.path,
        }
      end

      def visit_vnetwork(vnetwork)
        ret = {
          'name' => vnetwork.name,
          'address' => vnetwork.address.to_string,
          'vnodes' => [],
          'vroutes' => visit(vnetwork.vroutes),
        }
        vnetwork.vnodes.each_pair do |vnode,viface|
          ret['vnodes'] << vnode.name if viface
        end
        return ret
      end

      def visit_vroute(vroute)
        return {
          'id' => vroute.id.to_s,
          'networksrc' => vroute.srcnet.name,
          'networkdst' => vroute.dstnet.name,
          'gateway' => vroute.gw.to_s,
        }
      end

      def visit_rule(rule)
        return {
          'vnode' => rule.vnode.name,
          'viface' => rule.viface.name,
          'direction' => rule.direction,
          'properties' => visit(rule.properties),
        }
      end

      def visit_bandwidth(limitbw)
        return {
          'type' => limitbw.to_s(),
          'rate' => limitbw.rate,
        }
      end

      def visit_latency(limitlat)
        return {
          'type' => limitlat.to_s(),
          'delay' => limitlat.delay,
        }
      end
    end

  end
end

