
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
          end
          if viface.vinput
            apply_vtraffic(viface.vinput)
          end
        end

        # Apply the limitation following a specific traffic instruction
        # ==== Attributes
        # * +vtraffic+ The VTraffic object
        #
        def apply_vtraffic(vtraffic)

          limited_bw_output = @limited_bw_output
          limited_lat_output = @limited_lat_output
          limited_bw_input = @limited_bw_input
          limited_lat_input = @limited_lat_input

          @limited_bw_output = false
          @limited_lat_output = false
          @limited_bw_input = false
          @limited_lat_input = false

          iface = Lib::NetTools::get_iface_name(vtraffic.viface.vnode,
                                                vtraffic.viface)
          baseiface = iface
          action = nil
          direction = nil
          case vtraffic.direction
          when Resource::VIface::VTraffic::Direction::INPUT
            if !(limited_bw_input || limited_lat_input)
              tcroot = TCWrapper::QdiscRoot.new(iface)
              tmproot = tcroot
            end
            direction = 'input'
          when Resource::VIface::VTraffic::Direction::OUTPUT
            if !(limited_bw_output || limited_lat_output)
              tcroot = TCWrapper::QdiscIngress.new(iface)
              Lib::Shell.run(tcroot.get_cmd(TCWrapper::Action::ADD))
              vtraffic.viface.ifb = @@ifballocator.get_ifb if vtraffic.viface.ifb.nil?
              iface = vtraffic.viface.ifb
              tmproot = TCWrapper::QdiscRoot.new(iface)            
            end
            direction = 'output'
          else
            raise "Invalid direction"
          end

          primroot = nil
          bandwidth = nil
          bwlim = vtraffic.get_property(Resource::Bandwidth.name)
          if bwlim
            existing_root = nil
            if eval("limited_bw_#{direction}")
              action = TCWrapper::Action::CHANGE
              @@lock.synchronize {
                existing_root = @@store[vtraffic.viface]["bw_#{direction}"]
              }
            else
              action = TCWrapper::Action::ADD
            end
            self.instance_variable_set("@limited_bw_#{direction}", true)
            bandwidth = bwlim.to_bytes()
            params = {
              'rate' => "#{bwlim.rate}",
              # cf. http://www.juniper.net/techpubs/en_US/junos11.2/topics/reference/general/policer-guidelines-burst-size-calculating.html
              # buffer size = rate * latency (here latency is 50ms)
              # warning, the buffer size should be at least equal to the MTU (plus some bytes...)
              'buffer' => [Integer(bwlim.to_bytes * 0.05), Lib::NetTools::get_iface_mtu(vtraffic.viface.vnode, vtraffic.viface) + 20].max,
              'latency' => '50ms'
            }
            if existing_root
              tmproot = existing_root
              params.each_pair { |k,v|
                tmproot.add_param(k,v)
              }
            else
              tmproot = TCWrapper::QdiscTBF.new(iface,tmproot,params)
            end
            @@lock.synchronize {
              @@store[vtraffic.viface]["bw_#{direction}"] = tmproot
            }
            primroot = tmproot
            Lib::Shell.run(tmproot.get_cmd(action))
          end

          latlim = vtraffic.get_property(Resource::Latency.name)
          if latlim
            existing_root = nil
            if eval("limited_lat_#{direction}")
              # if bandwidth limitation has been set before, netem is removed, so we have
              # to add it again
              action = primroot ? TCWrapper::Action::ADD : TCWrapper::Action::CHANGE
              @@lock.synchronize {
                existing_root = @@store[vtraffic.viface]["lat_#{direction}"]
              }
            else
              action = TCWrapper::Action::ADD
            end
            self.instance_variable_set("@limited_lat_#{direction}", true)
            if existing_root
              tmproot = existing_root
              latlim.tc_params(bandwidth).each_pair { |k,v|
                tmproot.add_param(k,v)
              }
            else
              tmproot = TCWrapper::QdiscNetem.new(
                                                  iface, tmproot,
                                                  latlim.tc_params(bandwidth)
                                                  )
            end
            @@lock.synchronize {
              @@store[vtraffic.viface]["lat_#{direction}"] = tmproot
            }
            primroot = tmproot unless primroot
            Lib::Shell.run(tmproot.get_cmd(action))
          end
          
          if (vtraffic.direction == Resource::VIface::VTraffic::Direction::OUTPUT) && 
              !(limited_bw_output || limited_lat_output) 
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
          @@lock.synchronize {
            @@store[viface] = {}
          }

          iface = Lib::NetTools::get_iface_name(viface.vnode,viface)

          if (@limited_bw_output || @limited_lat_output)
            outputroot = TCWrapper::QdiscRoot.new(viface.ifb)
            Lib::Shell.run(outputroot.get_cmd(TCWrapper::Action::DEL))
            outputroot = TCWrapper::QdiscIngress.new(iface)
            Lib::Shell.run(outputroot.get_cmd(TCWrapper::Action::DEL))
            @limited_bw_output = false
            @limited_lat_output = false
          end

          if (@limited_bw_input || @limited_lat_input)
            inputroot = TCWrapper::QdiscRoot.new(iface)
            Lib::Shell.run(inputroot.get_cmd(TCWrapper::Action::DEL))
            @limited_bw_intput = false
            @limited_lat_intput = false
          end
        end
      end
    end
  end
end
