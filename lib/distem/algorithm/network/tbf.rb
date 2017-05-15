
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
          if viface.latency_filters
            apply_filters(viface)
          else
            if viface.voutput
              apply_vtraffic(viface.voutput)
            end
            if viface.vinput
              apply_vtraffic(viface.vinput)
            end
          end
        end


        def apply_filters(viface)
          baseiface = Lib::NetTools::get_iface_name(viface)
          latency_mapping = viface.latency_filters.values.uniq
          nb_filters = latency_mapping.length
          if nb_filters > 255
            raise "Too many different latency values for #{viface.vnode.name}"
          end

          ingressroot = TCWrapper::QdiscIngress.new(baseiface)
          add = ingressroot.get_cmd(TCWrapper::Action::ADD)
          Lib::Shell.run(add)
          viface.ifb = @@ifballocator.get_ifb if viface.ifb.nil?
          iface = viface.ifb
          qdiscroot = TCWrapper::QdiscRoot.new(iface)

          prio = TCWrapper::QdiscPrio.new(iface, qdiscroot, { 'bands' => 16 })
          add = prio.get_cmd(TCWrapper::Action::ADD)
          Lib::Shell.run(add)
          prio_roots = []
          netem = []
          if (nb_filters < 16)
            #1 prio level
            prio_roots << prio
            #create the Netem queues
            latency_mapping.each { |lat|
              current = TCWrapper::QdiscNetem.new(iface, prio, { 'delay' => "#{lat}ms"})
              netem << current
              add = current.get_cmd(TCWrapper::Action::ADD)
              Lib::Shell.run(add)
            }
            viface.latency_filters.each_pair { |dest,val|
              filter = TCWrapper::FilterU32.new(iface, prio, netem[latency_mapping.index(val)], "ip", 1)
              filter.add_match_ip_dst(dest)
              add = filter.get_cmd(TCWrapper::Action::ADD)
              Lib::Shell.run(add)
            }
            #default traffic
            fake_qdisc = TCWrapper::QdiscPrio.new(iface, prio)
            filter = TCWrapper::FilterU32.new(iface, prio, fake_qdisc, "ip", 2)
            filter.add_match_u32('0','0')
            cmd = filter.get_cmd(TCWrapper::Action::ADD)
            Lib::Shell.run(cmd)
          else
            #2 prio levels
            nb_2nd_level_prios = ((nb_filters + 1) / 16) + (((nb_filters + 1) % 16) > 0 ? 1 : 0)
            (0...nb_2nd_level_prios).each {
              current = TCWrapper::QdiscPrio.new(iface, prio, { 'bands' => 16})
              prio_roots << current
              add = current.get_cmd(TCWrapper::Action::ADD)
              Lib::Shell.run(add)
            }
            #create the Netem queues
            latency_mapping.each { |lat|
              current = TCWrapper::QdiscNetem.new(iface, prio_roots[latency_mapping.index(lat) / 16], { 'delay' => "#{lat}ms"})
              netem << current
              add = current.get_cmd(TCWrapper::Action::ADD)
              Lib::Shell.run(add)
            }
            #Filters
            viface.latency_filters.each_pair { |dest,val|
              filter = TCWrapper::FilterU32.new(iface, prio, prio_roots[latency_mapping.index(val) / 16], "ip", 1)
              filter.add_match_ip_dst(dest)
              add = filter.get_cmd(TCWrapper::Action::ADD)
              Lib::Shell.run(add)
              filter = TCWrapper::FilterU32.new(iface, prio_roots[latency_mapping.index(val) / 16], netem[latency_mapping.index(val)], "ip", 1)
              filter.add_match_ip_dst(dest)
              add = filter.get_cmd(TCWrapper::Action::ADD)
              Lib::Shell.run(add)
            }

            #default traffic
            fake_qdisc = TCWrapper::QdiscPrio.new(iface, prio_roots[nb_filters / 16])
            filter = TCWrapper::FilterU32.new(iface, prio_roots[nb_filters / 16], fake_qdisc, "ip", 2)
            filter.add_match_u32('0','0')
            cmd = filter.get_cmd(TCWrapper::Action::ADD)
            Lib::Shell.run(cmd)
          end
          filter = TCWrapper::FilterU32.new(baseiface, ingressroot, qdiscroot)
          filter.add_match_u32('0','0')
          filter.add_param("action","mirred egress")
          filter.add_param("redirect","dev #{iface}")
          Lib::Shell.run(filter.get_cmd(TCWrapper::Action::ADD))
        end


        # Apply the limitation following a specific traffic instruction
        # ==== Attributes
        # * +vtraffic+ The VTraffic object
        #
        def apply_vtraffic(vtraffic)

          limited_netem_output = @limited_netem_output
          limited_netem_input = @limited_netem_input

          @limited_netem_output = false
          @limited_netem_input = false

          iface = Lib::NetTools::get_iface_name(vtraffic.viface)
          baseiface = iface
          action = nil
          direction = nil
          case vtraffic.direction
          when Resource::VIface::VTraffic::Direction::INPUT
            direction = 'input'
          when Resource::VIface::VTraffic::Direction::OUTPUT
            if !(limited_netem_output) && vtraffic.limited?
              Lib::Shell.run("tc qdisc add dev #{iface} ingress")
              vtraffic.viface.ifb = @@ifballocator.get_ifb if vtraffic.viface.ifb.nil?
              iface = vtraffic.viface.ifb
            end
            direction = 'output'
          else
            raise "Invalid direction"
          end

          if vtraffic.limited?
            existing_netem_params = nil
            if eval("limited_netem_#{direction}")
              action = :change
              @@lock.synchronize {
                existing_netem_params = @@store[vtraffic.viface]["netem_#{direction}"]
              }
            else
              action = :add
            end
            self.instance_variable_set("@limited_netem_#{direction}", true)
            params = vtraffic.properties
            if existing_netem_params
              netem_params = existing_netem_params
              params.each_pair { |k,v|
                netem_params[k] = v
              }
            else
              netem_params = params
            end
            @@lock.synchronize {
              @@store[vtraffic.viface]["netem_#{direction}"] = netem_params
            }
            netem = TCWrapper::Netem.new(action, iface)

            bandwidth = netem_params[Resource::Bandwidth.name]
            if bandwidth && bandwidth.rate
              netem.bandwidth = {:rate => bandwidth.rate}
            end

            latency = netem_params[Resource::Latency.name]
            if latency && latency.delay
              netem.latency = {:delay => latency.delay}
              if latency.jitter
                netem.latency[:jitter] = latency.jitter
              end
            end

            loss = netem_params[Resource::Loss.name]
            if loss && loss.percent
              netem.loss = {:percent => loss.percent}
            end

            corruption = netem_params[Resource::Corruption.name]
            if corruption && corruption.percent
              netem.corruption = {:percent => corruption.percent}
            end

            duplication = netem_params[Resource::Duplication.name]
            if duplication && duplication.percent
              netem.duplication = {:percent => duplication.percent}
            end

            reordering = netem_params[Resource::Reordering.name]
            if reordering && reordering.percent
              netem.percent = {:percent => reordering.percent}
            end

            Lib::Shell.run(netem.get_cmd())
          end

          if (vtraffic.direction == Resource::VIface::VTraffic::Direction::OUTPUT) &&
             (vtraffic.limited?)
            Lib::Shell.run("tc filter add dev #{baseiface} parent ffff: protocol ip u32 match u32 0 0 flowid 1:0x1 action mirred egress redirect dev #{iface}")
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

          iface = Lib::NetTools::get_iface_name(viface)

          if (@limited_netem_output)
            outputroot = TCWrapper::QdiscRoot.new(viface.ifb)
            Lib::Shell.run(outputroot.get_cmd(TCWrapper::Action::DEL))
            outputroot = TCWrapper::QdiscIngress.new(iface)
            Lib::Shell.run(outputroot.get_cmd(TCWrapper::Action::DEL))
            @limited_netem_output = false
          end

          if (@limited_netem_input)
            inputroot = TCWrapper::QdiscRoot.new(iface)
            Lib::Shell.run(inputroot.get_cmd(TCWrapper::Action::DEL))
            @limited_netem_intput = false
          end
        end
      end
    end
  end
end
