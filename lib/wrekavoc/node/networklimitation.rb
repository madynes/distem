require 'wrekavoc'

module Wrekavoc
  module Node

    class NetworkLimitation
      def self.apply(viface)
        apply_tbf(viface.voutput) if viface.voutput
        apply_tbf(viface.vinput) if viface.vinput
      end

      def self.undo(viface)
        if viface.vinput
          iface = "ifb#{viface.id}"
          inputroot = TCWrapper::QdiscRoot.new(iface)
          Lib::Shell.run(inputroot.get_cmd(TCWrapper::Action::DEL))
        end

        if viface.voutput
          iface = Lib::NetTools::get_iface_name(viface.vnode,viface)
          outputroot = TCWrapper::QdiscRoot.new(iface)
          Lib::Shell.run(outputroot.get_cmd(TCWrapper::Action::DEL))
        end
      end

      def self.apply_tbf(vtraffic)
        iface = Lib::NetTools::get_iface_name(vtraffic.viface.vnode,
          vtraffic.viface)
        baseiface = iface

        case vtraffic.direction
          when Resource::VIface::VTraffic::Direction::OUTPUT
            tcroot = TCWrapper::QdiscRoot.new(iface)
            tmproot = tcroot
          when Resource::VIface::VTraffic::Direction::INPUT
            tcroot = TCWrapper::QdiscIngress.new(iface)
            Lib::Shell.run(tcroot.get_cmd(TCWrapper::Action::ADD))
            iface = "ifb#{vtraffic.viface.id}"
            tmproot = TCWrapper::QdiscRoot.new(iface)
          else
            raise "Invalid direction"
        end


        primroot = nil
        bwlim = vtraffic.get_property(Resource::Bandwidth.name)
        if bwlim
          tmproot = TCWrapper::QdiscTBF.new(iface,tmproot, \
              { 'rate' => "#{bwlim.rate}", 'buffer' => 1800, \
                'latency' => '50ms'})
          primroot = tmproot unless primroot
          Lib::Shell.run(tmproot.get_cmd(TCWrapper::Action::ADD))
        end

        latlim = vtraffic.get_property(Resource::Latency.name)
        if latlim
          tmproot = TCWrapper::QdiscNetem.new(iface,tmproot, \
            {'delay' => "#{latlim.delay}"})
          primroot = tmproot unless primroot
          Lib::Shell.run(tmproot.get_cmd(TCWrapper::Action::ADD))
        end

        if vtraffic.direction == Resource::VIface::VTraffic::Direction::INPUT
          filter = TCWrapper::FilterU32.new(baseiface,tcroot,primroot)
          filter.add_match_u32('0','0')
          filter.add_param("action","mirred egress")
          filter.add_param("redirect","dev #{iface}")
          Lib::Shell.run(filter.get_cmd(TCWrapper::Action::ADD))
        end

      end

      def self.apply_htb(vtraffic)
      end
    end

  end
end
