require 'distem'

module Distem
  module Algorithm
    module Network

      # An algorithm that's using TC Token Bucket Filter (see http://en.wikipedia.org/wiki/Token_bucket) to limit network traffic
      class TBF < TCAlgorithm
        # Create a new TBF object
        def initialize()
          super()
        end

        # Apply limitations on a specific virtual network interface
        # ==== Attributes
        # * +viface+ The VIface object
        #
        def apply(viface)
          super(viface)
          if viface.voutput
            apply_vtraffic(viface.voutput)
            @limited_output = true
          end
          if viface.vinput
            apply_vtraffic(viface.vinput)
            @limited_input = true
          end
        end

        # Apply the limitation following a specific traffic instruction
        # ==== Attributes
        # * +vtraffic+ The VTraffic object
        #
        def apply_vtraffic(vtraffic)
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
          bandwidth = nil
          bwlim = vtraffic.get_property(Resource::Bandwidth.name)
          if bwlim
            bandwidth = bwlim.to_bytes()
            tmproot = TCWrapper::QdiscTBF.new(
              iface,tmproot,
              { 'rate' => "#{bwlim.rate}",
                'buffer' => 3600,
                'latency' => '50ms' }
            )
            primroot = tmproot unless primroot
            Lib::Shell.run(tmproot.get_cmd(TCWrapper::Action::ADD))
          end

          latlim = vtraffic.get_property(Resource::Latency.name)
          if latlim
            tmproot = TCWrapper::QdiscNetem.new(
              iface, tmproot,
              latlim.tc_params(bandwidth)
            )
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


        # Undo limitations effective on a specific virtual network interface
        # ==== Attributes
        # * +viface+ The VIface object
        #
        def undo(viface)
          super(viface)
          iface = Lib::NetTools::get_iface_name(viface.vnode,viface)

          if @limited_input
            inputroot = TCWrapper::QdiscRoot.new("ifb#{viface.id}")
            Lib::Shell.run(inputroot.get_cmd(TCWrapper::Action::DEL))
            inputroot = TCWrapper::QdiscIngress.new(iface)
            Lib::Shell.run(inputroot.get_cmd(TCWrapper::Action::DEL))
            @limited_input = false
          end

          if @limited_output
            outputroot = TCWrapper::QdiscRoot.new(iface)
            Lib::Shell.run(outputroot.get_cmd(TCWrapper::Action::DEL))
            @limited_output = false
          end
        end
      end
    end
  end
end
