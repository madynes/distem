module Distem
  module NetAPI

    # REST server routines
    class RESTServer
      CONTENT_TYPE='application/vnd.grid5000+json'

      # Get the URI to some content
      # @param [Distem::Resource] res The resource content
      def self.get_baseroute(res=nil)
        ret = '/'
        # >>>TODO: Add VRoute
        if res.is_a?(Class)
          case res.name.split('::').last
          when 'VPlatform'
            ret = '/'
          when 'PNode'
            ret = '/pnodes'
          when 'VNode'
            ret = '/vnodes'
          when 'VNetwork'
            ret = '/vnetwork'
          else
            ret = nil
          end
        else
          if res.is_a?(Resource::VIface)
            ret = "#{get_route(res.vnode)}/ifaces"
          elsif res.is_a?(Resource::VRoute)
            ret = "#{get_route(res.srcnet)}/routes"
          else
            ret = get_baseroute(res.class)
          end
        end

        return ret
      end

      def self.get_route(res=nil)
        ret = '/'
        # >>>TODO: Add VRoute
        if res.is_a?(Resource::VPlatform)
          ret = get_baseroute(res)
        elsif res.is_a?(Resource::PNode)
          ret = "#{get_baseroute(res)}/#{res.address.to_s}"
        elsif res.is_a?(Resource::CPU)
          ret = "#{get_route(res.pnode)}/cpu"
        elsif res.is_a?(Resource::Memory)
          ret = "#{get_route(res.pnode)}/memory"
        elsif res.is_a?(Resource::VNode)
          ret = "#{get_baseroute(res)}/#{res.name}"
        elsif res.is_a?(Resource::VIface)
          ret = "#{get_baseroute(res)}/#{res.name}"
        elsif res.is_a?(Resource::VCPU)
          ret = "#{get_route(res.vnode)}/cpu"
        elsif res.is_a?(Resource::FileSystem)
          ret = "#{get_route(res.vnode)}/filesystem"
        elsif res.is_a?(Resource::VNetwork)
          ret = "#{get_baseroute(res)}/#{res.name}"
        elsif res.is_a?(Resource::VIface::VTraffic)
          if res.direction == Resource::VIface::VTraffic::Direction::INPUT
            ret = "#{get_route(res.viface)}/input"
          elsif res.direction == Resource::VIface::VTraffic::Direction::OUTPUT
            ret = "#{get_route(res.viface)}/output"
          end
        elsif res.is_a?(Array) and !res.empty?
          ret = get_baseroute(res[0])
        else
          ret = get_baseroute(res)
        end

        return ret
      end

      def self.get_uid(res)
        ret = ''
        if res.is_a?(Resource::PNode)
          ret = res.address.to_s
        elsif res.is_a?(Resource::VNode) \
        or res.is_a?(Resource::VIface) \
        or res.is_a?(Resource::VNetwork)
          ret = res.name
        else
          ret = res.id.to_s
        end

        return ret
      end

      def self.set_baseret(res,ret={})
        route = NetAPI::RESTServer.get_route(res)
        ret['uid'] = NetAPI::RESTServer.get_uid(res)
        ret['href'] = route
        ret['links'] = [
          {
            'href' => route,
            'rel' => 'self',
            'type' => CONTENT_TYPE,
          },
        ]
        return ret
      end
    end

  end
end
