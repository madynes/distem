require 'wrekavoc'

module Wrekavoc
  module TopologyStore

    class XMLWriter < TopologyWriter
      def visit_vplatform(vplatform)
        evplatform = REXML::Element.new("vplatform")
        visit(vplatform.pnodes).each { |elem| evplatform.add_element(elem) }
        visit(vplatform.vnodes).each { |elem| evplatform.add_element(elem) }
        visit(vplatform.vnetworks).each { |elem| evplatform.add_element(elem) }
        
        ret = REXML::Document.new
        ret << REXML::XMLDecl.new
        ret.add_element(evplatform)
        return ret.to_s
      end

      def visit_pnode(pnode)
        ret = REXML::Element.new("pnode")
        ret.add_attribute('address',pnode.address)
        ret.add_element(visit(pnode.cpu))
        ret.add_element(visit(pnode.memory))
        return ret
      end

      def visit_vnode(vnode)
        ret = REXML::Element.new("vnode")
        ret.add_attribute('name',vnode.name)
        ret.add_element('host').add_text(vnode.host.address.to_s)
        ret.add_element(visit(vnode.filesystem))
        visit(vnode.vifaces).each { |elem| ret.add_element(elem) }
        ret.add_element(visit(vnode.vcpu))
        ret.add_element('gateway').add_text(vnode.gateway.to_s)
        return ret
      end

      def visit_viface(viface)
        ret = REXML::Element.new("viface")
        ret.add_attribute('name',viface.name)
        ret.add_element('address').add_text(viface.address.to_string)
        ret.add_element('vnetwork').add_text(viface.vnetwork.name) if viface.vnetwork
        ret.add_element(visit(viface.vinput)) if viface.vinput
        ret.add_element(visit(viface.voutput)) if viface.voutput
        return ret
      end

      def visit_cpu(cpu)
        ret = REXML::Element.new("cpu")
        ret.add_attribute('id',cpu.id.to_s)
        visit(cpu.cores).each { |elem| ret.add_element(elem) }
        return ret
      end

      def visit_core(core)
        ret = REXML::Element.new("core")
        ret.add_attribute('id',core.physicalid.to_s)
        ret.add_element('frequency').add_text(core.frequency.to_s + ' MHz')

        return ret
      end

      def visit_vcpu(vcpu)
        ret = REXML::Element.new("vcpu")
        ret.add_element('pcpu').add_text(vcpu.pcpu.id.to_s)
        visit(vcpu.vcores).each { |elem| ret.add_element(elem) }
        return ret
      end

      def visit_vcore(vcore)
        ret = REXML::Element.new("vcore")
        ret.add_element('pcore').add_text(vcore.pcore.physicalid.to_s)
        ret.add_element('frequency').add_text(vcore.frequency.to_s + ' MHz')
        return ret
      end

      def visit_memory(memory)
        ret = REXML::Element.new("memory")
        ret.add_element('capacity').add_text(memory.capacity.to_s + ' Mo')
        ret.add_element('swap').add_text(memory.swap.to_s + ' Mo')
        return ret
      end

      def visit_filesystem(filesystem)
        ret = REXML::Element.new("filesystem")
        ret.add_element('image').add_text(filesystem.image)
        return ret
      end

      def visit_vnetwork(vnetwork)
        ret = REXML::Element.new("vnetwork")
        ret.add_attribute('name',vnetwork.name)
        ret.add_element('address').add_text(vnetwork.address.to_string)
        visit(vnetwork.vroutes).each { |elem| ret.add_element(elem) }
        return ret
      end

      def visit_vroute(vroute)
        ret = REXML::Element.new("vroute")
        ret.add_attribute('id',vroute.id.to_s)
        ret.add_element('networksrc').add_text(vroute.srcnet.name)
        ret.add_element('networkdst').add_text(vroute.dstnet.name)
        ret.add_element('gateway').add_text(vroute.gw.to_s)
        return ret
      end

      def visit_vtraffic(vtraffic)
        ret = REXML::Element.new("vtraffic")
        ret.add_attribute('direction',vtraffic.direction)
        ret.add_element('viface').add_text(vtraffic.viface.name)
        visit(vtraffic.properties).each { |elem| ret.add_element(elem) }
        return ret
      end

      def visit_bandwidth(limitbw)
        ret = REXML::Element.new("bandwidth")
        ret.add_element('type').add_text(limitbw.to_s())
        ret.add_element('rate').add_text(limitbw.rate)
        return ret
      end

      def visit_latency(limitlat)
        ret = REXML::Element.new("latency")
        ret.add_element('type').add_text(limitlat.to_s())
        ret.add_element('delay').add_text(limitlat.delay)
        return ret
      end
    end

  end
end
