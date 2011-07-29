require 'wrekavoc'

module Wrekavoc
  module TopologyStore

    class HashWriter < TopologyWriter
      def visit_vplatform(vplatform)
        return { 'vplatform' => {
          'pnodes' => visit(vplatform.pnodes),
          'vnodes' => visit(vplatform.vnodes),
          'vnetworks' => visit(vplatform.vnetworks),
        } }
      end

      def visit_pnode(pnode)
        return {
          'id' => pnode.id.to_s,
          'address' => pnode.address,
          'cpu' => visit(pnode.cpu),
          'memory' => visit(pnode.memory),
          'status' => pnode.status,
        }
      end

      def visit_vnode(vnode)
        return {
          'id' => vnode.id.to_s,
          'name' => vnode.name,
          'status' => vnode.status,
          'host' => vnode.host.address.to_s,
          'filesystem' => visit(vnode.filesystem),
          'vifaces' => visit(vnode.vifaces),
          'vcpu' => visit(vnode.vcpu),
          'gateway' => vnode.gateway,
        }
      end

      def visit_viface(viface)
        return {
          'id' => viface.id.to_s,
          'name' => viface.name,
          'vnode' => viface.vnode.name,
          'address' => viface.address.to_string,
          'vnetwork' => (viface.vnetwork ? viface.vnetwork.name : nil),
          'vinput' => (viface.vinput ? visit(viface.vinput) : nil),
          'voutput' => (viface.voutput ? visit(viface.voutput) : nil),
        }
      end

      def visit_cpu(cpu)
        ret = {
          'id' => cpu.id.to_s,
          'cores' => visit(cpu.cores),
          'cores_alloc' => [],
          'critical_cache_links' => [],
        }

        cpu.cores_alloc.each do |core,vnode|
          ret['cores_alloc'] << { 'core' => core.physicalid, 'vnode' => vnode.name }
        end

        cpu.critical_cache_links.each do |cachelink|
          ret['critical_cache_links'] <<
            cachelink.collect { |core| core.physicalid }
        end
        
        return ret
      end

      def visit_core(core)
        ret = {
          'physicalid' => core.physicalid,
          'frequency' => core.frequency.to_s + ' MHz',
          'cache_links' => [],
        }

        core.cache_links.each do |linkedcore|
          ret['cache_links'] << linkedcore.physicalid
        end

        return ret
      end

      def visit_vcpu(vcpu)
        return {
          'pcpu' => vcpu.pcpu.id.to_s,
          'vcores' => visit(vcpu.vcores),
        }
      end

      def visit_vcore(vcore)
        return {
          'pcore' => vcore.pcore.physicalid.to_s,
          'frequency' => vcore.frequency.to_s + ' MHz',
        }
      end

      def visit_memory(memory)
        return {
          'capacity' => memory.capacity.to_s + ' Mo',
          'swap' => memory.swap.to_s + ' Mo',
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

      def visit_vtraffic(vtraffic)
        return {
          'viface' => vtraffic.viface.name,
          'direction' => vtraffic.direction,
          'properties' => visit(vtraffic.properties),
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

