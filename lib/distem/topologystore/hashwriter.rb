require 'distem'

module Distem
  module TopologyStore

    # Class that saves some virtual resource object as an Hash representing their properties. Based on the Visitor design pattern.
    class HashWriter < TopologyWriter
      # Visit a virtual platform object. /All the other "visit_" methods are working the same way./
      # ==== Attributes
      # *+vplatform+ The VPlatform object
      # ==== Returns
      # Hash object representing the VPlatform properties
      #
      def visit_vplatform(vplatform)
        return { 'vplatform' => {
          'pnodes' => visit(vplatform.pnodes),
          'vnodes' => visit(vplatform.vnodes),
          'vnetworks' => visit(vplatform.vnetworks),
        } }
      end

      # See the visit_vplatform documentation
      def visit_pnode(pnode)
        return {
          'id' => pnode.id.to_s,
          'address' => pnode.address,
          'cpu' => visit(pnode.cpu),
          'memory' => visit(pnode.memory),
          'status' => pnode.status,
        }
      end

      # See the visit_vplatform documentation
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

      # See the visit_vplatform documentation
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

      # See the visit_vplatform documentation
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

      # See the visit_vplatform documentation
      def visit_core(core)
        ret = {
          'physicalid' => core.physicalid,
          'coreid' => core.coreid,
          'frequency' => (core.frequency / 1000).to_s + ' MHz',
          'frequencies' => [],
          'cache_links' => [],
        }
        core.frequencies.each do |corefreq|
          ret['frequencies'] << (corefreq / 1000).to_s + ' MHz'
        end

        core.cache_links.each do |linkedcore|
          ret['cache_links'] << linkedcore.physicalid
        end

        return ret
      end

      # See the visit_vplatform documentation
      def visit_vcpu(vcpu)
        return {
          'pcpu' => vcpu.pcpu.id.to_s,
          'vcores' => visit(vcpu.vcores),
        }
      end

      # See the visit_vplatform documentation
      def visit_vcore(vcore)
        return {
          'id' => vcore.id.to_s,
          'pcore' => (vcore.pcore ? vcore.pcore.physicalid.to_s : nil),
          'frequency' => (vcore.frequency / 1000).to_s + ' MHz',
        }
      end

      # See the visit_vplatform documentation
      def visit_memory(memory)
        return {
          'capacity' => memory.capacity.to_s + ' Mo',
          'swap' => memory.swap.to_s + ' Mo',
        }
      end

      # See the visit_vplatform documentation
      def visit_filesystem(filesystem)
        return {
          'vnode' => filesystem.vnode,
          'image' => filesystem.image,
          'path' => filesystem.path,
        }
      end

      # See the visit_vplatform documentation
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

      # See the visit_vplatform documentation
      def visit_vroute(vroute)
        return {
          'id' => vroute.id.to_s,
          'networksrc' => vroute.srcnet.name,
          'networkdst' => vroute.dstnet.name,
          'gateway' => vroute.gw.to_s,
        }
      end

      # See the visit_vplatform documentation
      def visit_vtraffic(vtraffic)
        return {
          'viface' => vtraffic.viface.name,
          'direction' => vtraffic.direction,
          'properties' => visit(vtraffic.properties),
        }
      end

      # See the visit_vplatform documentation
      def visit_bandwidth(limitbw)
        return {
          'type' => limitbw.to_s(),
          'rate' => limitbw.rate,
        }
      end

      # See the visit_vplatform documentation
      def visit_latency(limitlat)
        return {
          'type' => limitlat.to_s(),
          'delay' => limitlat.delay,
        }
      end
    end

  end
end

