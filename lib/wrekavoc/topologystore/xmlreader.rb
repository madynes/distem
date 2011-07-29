require 'wrekavoc'
require 'rexml/document'

module Wrekavoc
  module TopologyStore

    class XMLReader < TopologyReader
      def parse(inputstr)
        xmldoc = REXML::Document.new(inputstr)
        return parse_vplatform(xmldoc)
      end

      def parse_vplatform(xmldoc,tmp={})
        ret = {}
        ret['vplatform'] = {}
        ret['vplatform']['pnodes'] = []
        ret['vplatform']['vnodes'] = []
        ret['vplatform']['vnetworks'] = []

        xmldoc.elements.each("*/pnode") do |pnode|
          ret['vplatform']['pnodes'] << parse_pnode(pnode)
        end

        xmldoc.elements.each("*/vnode") do |vnode|
          ret['vplatform']['vnodes'] << parse_vnode(vnode)
        end

        xmldoc.elements.each("*/vnetwork") do |vnetwork|
          ret['vplatform']['vnetworks'] << parse_vnetwork(vnetwork)
        end
        return ret
      end

      def parse_pnode(xmldoc,tmp={})
        ret = tmp
        ret['address'] = xmldoc.attribute('address').to_s
        xmldoc.elements.each("cpu") do |cpu|
          ret['cpu'] = parse_cpu(cpu)
          break
        end
        xmldoc.elements.each("memory") do |memory|
          ret['memory'] = parse_memory(memory)
          break
        end
        return ret
      end

      def parse_cpu(xmldoc,tmp={})
        ret = tmp
        ret['id'] = xmldoc.attribute('id').to_s
        ret['cores'] = []
        xmldoc.elements.each("core") do |core|
          ret['cores'] << parse_core(core)
        end
        return ret
      end

      def parse_core(xmldoc,tmp={})
        ret = tmp
        ret['id'] = xmldoc.attribute('id').to_s
        ret['frequency'] = xmldoc.attribute('frequency').to_s.split[0].to_f
        return ret
      end

      def parse_memory(xmldoc,tmp={})
        ret = tmp
        ret['capacity'] = xmldoc.attribute('capacity').to_s.split[0].to_f
        ret['swap'] = xmldoc.attribute('swap').to_s.split[0].to_f
        return ret
      end

      def parse_vnode(xmldoc,tmp={})
        ret = tmp
        ret['name'] = xmldoc.attribute('name').to_s
        ret['host'] = xmldoc.attribute('host').to_s
        xmldoc.elements.each("filesystem") do |fs|
          ret['filesystem'] = parse_filesystem(fs)
          break
        end
        xmldoc.elements.each("vcpu") do |vcpu|
          ret['vcpu'] = parse_vcpu(vcpu)
          break
        end
        ret['gateway'] = (xmldoc.attribute('gateway').to_s.upcase == 'TRUE')
        ret['vifaces'] = []
        xmldoc.elements.each("viface") do |viface|
          ret['vifaces'] << parse_viface(viface)
        end
        return ret
      end

      def parse_viface(xmldoc,tmp={})
        ret = tmp
        ret['name'] = xmldoc.attribute('name').to_s
        ret['address'] = xmldoc.attribute('address').to_s
        ret['vnetwork'] = xmldoc.attribute('vnetwork').to_s
        xmldoc.elements.each("vtraffic") do |vtraffic|
          parse_vtraffic(vtraffic,ret)
        end
        return ret
      end

      def parse_vcpu(xmldoc,tmp={})
        ret = tmp
        ret['pcpu'] = xmldoc.attribute('pcpu').to_s
        ret['vcores'] = []
        xmldoc.elements.each("vcore") do |vcore|
          ret['vcores'] << parse_vcore(vcore)
        end
        return ret
      end

      def parse_vcore(xmldoc,tmp={})
        ret = tmp
        ret['pcore'] = xmldoc.attribute('pcore').to_s
        ret['frequency'] = xmldoc.attribute('frequency').to_s.split[0].to_f
        return ret
      end

      def parse_filesystem(xmldoc,tmp={})
        ret = tmp
        ret['image'] = xmldoc.attribute('image').to_s
        return ret
      end

      def parse_vnetwork(xmldoc,tmp={})
        ret = tmp
        ret['name'] = xmldoc.attribute('name').to_s
        ret['address'] = xmldoc.attribute('address').to_s
        ret['vroutes'] = []
        xmldoc.elements.each("vroute") do |vroute|
          ret['vroutes'] << parse_vroute(vroute)
        end
        return ret
      end

      def parse_vroute(xmldoc,tmp={})
        ret = tmp
        ret['id'] = xmldoc.attribute('id').to_s
        ret['networksrc'] = xmldoc.attribute('networksrc').to_s
        ret['networkdst'] = xmldoc.attribute('networkdst').to_s
        ret['gateway'] = xmldoc.attribute('gateway').to_s
        return ret
      end

      def parse_vtraffic(xmldoc,tmp={})
        if (xmldoc.attribute('direction').to_s.upcase == 'INPUT')
          ret = tmp['vinput'] = {}
        else
          ret = tmp['voutput'] = {}
        end
        ret['properties'] = []
        xmldoc.each_element do |elem|
          ret['properties'] << self.send( "parse_#{elem.name.downcase}".to_sym, elem)
        end
      end

      def parse_bandwidth(xmldoc,tmp={})
        ret = tmp
        ret['type'] = xmldoc.name.downcase
        ret['rate'] = xmldoc.attribute('rate').to_s
        return ret 
      end

      def parse_latency(xmldoc,tmp={})
        ret = tmp
        ret['type'] = xmldoc.name.downcase
        ret['delay'] = xmldoc.attribute('delay').to_s
        return ret 
      end

      def method_missing(method, *args)
        raise args[0].class.name
      end
    end

  end
end
