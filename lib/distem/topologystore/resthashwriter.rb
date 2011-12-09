require 'distem'
require 'json'

module Distem
  module TopologyStore

    # Class that saves some virtual resource object as an JSON structure representing their properties. Based on the Visitor design pattern.
    class RESTHashWriter < HashWriter
      @@tmpcount = 0
      # Hack to use REST only on top level call
      def visit( object, hashret=true )
        ret = nil
        meth = "visit_#{object.class.name.split('::').last.downcase}".to_sym

        if hashret
          # Hack to call parent class method
          tmpmeth = "_tmp_#{meth}_#{@@tmpcount}".to_sym
          @@tmpcount += 1
          self.class.superclass.send(:alias_method, tmpmeth, meth)
          ret = self.send(tmpmeth, object)
          self.class.superclass.send(:remove_method, tmpmeth)
        else
          ret = self.send(meth, object)
        end

        return ret
      end

      # Visit an Array object, call the "visit" method for each values in the Hash.
      # ==== Attributes
      # * +array+ The Array object
      # ==== Returns
      # Object value of the kind of the concrete class (i.e. HashWriter returns an Hash object)
      def visit_array(array)
        tmp = super(array)

        ret = NetAPI::RESTServer.set_baseret(array)
        ret['offset'] = 0
        ret['total'] = array.size
        ret['items'] = []

        array.each do |elem|
          ret['items'] << {
            'uid' => NetAPI::RESTServer.get_uid(elem),
            'href' => NetAPI::RESTServer.get_route(elem),
            'type' => NetAPI::RESTServer::CONTENT_TYPE,
          }
        end

        return ret
      end

      # Visit a virtual platform object. /All the other "visit_" methods are working the same way./
      # ==== Attributes
      # *+vplatform+ The VPlatform object
      # ==== Returns
      # Hash object representing the VPlatform properties
      #
      def visit_vplatform(vplatform)
        ret = super(vplatform)
        ret = NetAPI::RESTServer.set_baseret(vplatform,ret)
        ret['type'] = NetAPI::RESTServer::CONTENT_TYPE,
        ret['links'] += [
          {
            'href' => NetAPI::RESTServer.get_baseroute(Resource::PNode),
            'rel' => 'pnodes',
            'type' => NetAPI::RESTServer::CONTENT_TYPE,
          },
          {
            'href' => NetAPI::RESTServer.get_baseroute(Resource::VNode),
            'rel' => 'vnodes',
            'type' => NetAPI::RESTServer::CONTENT_TYPE,
          },
          {
            'href' => NetAPI::RESTServer.get_baseroute(Resource::VNetwork),
            'rel' => 'vnetworks',
            'type' => NetAPI::RESTServer::CONTENT_TYPE,
          },
        ]

        return ret
      end

      # See the visit_vplatform documentation
      def visit_pnode(pnode)
        ret = super(pnode)
        ret = NetAPI::RESTServer.set_baseret(pnode,ret)

        ret['links'] += [
          {
            'href' => NetAPI::RESTServer.get_route(Resource::VPlatform),
            'rel' => 'parent',
            'type' => NetAPI::RESTServer::CONTENT_TYPE,
          },
          {
            'href' => NetAPI::RESTServer.get_route(pnode.memory),
            'rel' => 'memory',
            'type' => NetAPI::RESTServer::CONTENT_TYPE,
          },
          {
            'href' => NetAPI::RESTServer.get_route(pnode.cpu),
            'rel' => 'cpu',
            'type' => NetAPI::RESTServer::CONTENT_TYPE,
          },
        ]

        return ret
      end

      # See the visit_vplatform documentation
      def visit_vnode(vnode)
        ret = super(vnode)

        ret = NetAPI::RESTServer.set_baseret(vnode,ret)

        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(Resource::VPlatform),
          'rel' => 'parent',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        }

        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(vnode.vifaces),
          'rel' => 'vifaces',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        }

        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(vnode.filesystem),
          'rel' => 'vfilesystem',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        } if vnode.filesystem

        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(vnode.vcpu),
          'rel' => 'vcpu',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        } if vnode.vcpu

        return ret
      end

      # See the visit_vplatform documentation
      def visit_viface(viface)
        ret = super(viface)
        ret = NetAPI::RESTServer.set_baseret(viface,ret)

        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(viface.vnode),
          'rel' => 'parent',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        }

        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(viface.vinput),
          'rel' => 'vinput',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        } if viface.vinput

        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(viface.voutput),
          'rel' => 'voutput',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        } if viface.voutput

        return ret
      end

      # See the visit_vplatform documentation
      def visit_cpu(cpu)
        ret = super(cpu)

        ret = NetAPI::RESTServer.set_baseret(cpu,ret)
        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(cpu.pnode),
          'rel' => 'parent',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        }

        return ret
      end

      # See the visit_vplatform documentation
      def visit_vcpu(vcpu)
        ret = super(vcpu)

        ret = NetAPI::RESTServer.set_baseret(vcpu,ret)
        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(vcpu.vnode),
          'rel' => 'parent',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        }
        return ret
      end

      # See the visit_vplatform documentation
      def visit_memory(memory)
        ret = super(memory)
        ret = NetAPI::RESTServer.set_baseret(memory,ret)
        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(memory.pnode),
          'rel' => 'parent',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        }

        return ret
      end

      # See the visit_vplatform documentation
      def visit_filesystem(filesystem)
        ret = super(filesystem)

        ret = NetAPI::RESTServer.set_baseret(filesystem,ret)
        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(filesystem.vnode),
          'rel' => 'parent',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        }

        return ret
      end

      # See the visit_vplatform documentation
      def visit_vnetwork(vnetwork)
        ret = super(vnetwork)

        ret = NetAPI::RESTServer.set_baseret(vnetwork,ret)
        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(Resource::VPlatform),
          'rel' => 'parent',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        }

        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(vnetwork.vroutes),
          'rel' => 'vroutes',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        }

        return ret
      end

      # See the visit_vplatform documentation
      def visit_vroute(vroute)
        ret = super(vroute)

        ret = NetAPI::RESTServer.set_baseret(vroute,ret)
        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(vroute.srcnet),
          'rel' => 'parent',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        }

        return ret
      end

      # See the visit_vplatform documentation
      def visit_vtraffic(vtraffic)
        ret = super(vtraffic)
        ret = NetAPI::RESTServer.set_baseret(vtraffic,ret)

        ret['links'] << {
          'href' => NetAPI::RESTServer.get_route(vtraffic.viface),
          'rel' => 'parent',
          'type' => NetAPI::RESTServer::CONTENT_TYPE,
        }

        return ret
      end

      # See the visit_vplatform documentation
      def visit_bandwidth(limitbw)
        ret = super(limitbw)
        ret = NetAPI::RESTServer.set_baseret(limitbw,ret)
        return ret
      end

      # See the visit_vplatform documentation
      def visit_latency(limitlat)
        ret = super(limitlat)
        ret = NetAPI::RESTServer.set_baseret(limitlat,ret)
        return ret
      end
    end

  end
end

