
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
          'algorithms' => pnode.algorithms,
        }
      end

      # See the visit_vplatform documentation
      def visit_vnode(vnode)
        ret = {
          'id' => vnode.id.to_s,
          'name' => vnode.name,
          'status' => vnode.status,
          'vfilesystem' => visit(vnode.filesystem),
          'vifaces' => visit(vnode.vifaces),
          'vcpu' => visit(vnode.vcpu),
          'vmem' => visit(vnode.vmem),
          'mode' => (vnode.gateway ? Resource::VNode::MODE_GATEWAY : Resource::VNode::MODE_NORMAL),
        }

        if vnode.host
          ret['host'] = vnode.host.address.to_s
        else
          ret['host'] = nil
        end

        if vnode.sshkey
          ret['ssh_key'] = {}
          ret['ssh_key']['public'] = vnode.sshkey['public'] if vnode.sshkey['public']
          ret['ssh_key']['private'] = vnode.sshkey['private'] if vnode.sshkey['private']
        else
          ret['ssh_key'] = nil
        end

        return ret
      end

      # See the visit_vplatform documentation
      def visit_viface(viface)
          # Direction input/output is switched because of the lxc-veth structure that cause the input and the output of the network interface to be switched inside of the container
        return {
          'id' => viface.id.to_s,
          'name' => viface.name,
          'vnode' => viface.vnode.name,
          'address' => viface.address.to_string,
          'macaddress' => viface.macaddress,
          'vnetwork' => (viface.vnetwork ? viface.vnetwork.name : nil),
          'input' => (viface.vinput ? visit(viface.vinput) : nil),
          'output' => (viface.voutput ? visit(viface.voutput) : nil),
          'bridge' => viface.bridge,
        }
      end

      # See the visit_vplatform documentation
      def visit_cpu(cpu)
        ret = {
          'id' => cpu.object_id.to_s,
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
          'pcpu' => vcpu.pcpu.object_id.to_s,
          'vcores' => visit(vcpu.vcores),
        }
      end

      # See the visit_vplatform documentation
      def visit_vcore(vcore)
        pcorenum = nil
        if vcore.pcore
          if vcore.pcore.is_a?(Resource::CPU::Core)
            pcorenum = vcore.pcore.physicalid.to_s
          else
            pcorenum = vcore.pcore.to_s
          end
        end

        return {
          'id' => vcore.id.to_s,
          'pcore' => pcorenum,
          'frequency' => vcore.frequency ? (vcore.frequency / 1000).to_s : '0',
        }
      end

      # See the visit_vplatform documentation
      def visit_memory(memory)
        return {
          'capacity' => memory.capacity.to_s,
          'swap' => memory.swap.to_s,
        }
      end

      def visit_vmem(vmem)
        return {
          'mem' => vmem.mem.to_s,
          'swap' => vmem.swap.to_s,
        }
      end

      # See the visit_vplatform documentation
      def visit_filesystem(filesystem)
        return {
          'vnode' => filesystem.vnode,
          'image' => filesystem.image,
          'shared' => filesystem.shared,
          'path' => filesystem.path,
          'sharedpath' => filesystem.sharedpath,
          'cow' => filesystem.cow,
          'disk_throttling' => filesystem.disk_throttling,
        }
      end

      # See the visit_vplatform documentation
      def visit_vnetwork(vnetwork)
        ret = {
          'name' => vnetwork.name,
          'address' => vnetwork.address.to_string,
          'vnodes' => [],
          'vroutes' => visit(vnetwork.vroutes),
          'vxlan_id' => vnetwork.vxlan_id.to_i,
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
        ret = {}
        vtraffic.properties.each_value do |prop|
          name = prop.class.name.split('::').last.downcase
          ret[name] = {} unless ret[name]
          ret[name].merge!(visit(prop))
        end
        return ret
      end

      # See the visit_vplatform documentation
      def visit_bandwidth(limitbw)
        return {
          'rate' => limitbw.rate,
        }
      end

      # See the visit_vplatform documentation
      def visit_latency(limitlat)
        return {
          'delay' => limitlat.delay,
        }
      end
    end

  end
end

