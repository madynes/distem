
module Distem
  module Algorithm 
    module Network

      # A common interface for TC based algorithms
      class TCAlgorithm < Algorithm

        @@lock = Mutex.new
        @@store = {}
        @@ifballocator = nil

        def initialize()
          @limited_bw_output = false
          @limited_lat_output = false
          @limited_bw_input = false
          @limited_lat_input = false
          if @@ifballocator.nil?
            @@ifballocator = Node::IFBAllocator::new
          end
        end

        # :nodoc:
        def apply(viface)
          @@lock.synchronize {
            @@store[viface] = {} if !@@store[viface]
          }

          bw_output = (viface.voutput != nil) && (viface.voutput.get_property(Resource::Bandwidth.name) != nil) && (viface.voutput.get_property(Resource::Bandwidth.name).rate != nil)
          lat_output = (viface.voutput != nil) && (viface.voutput.get_property(Resource::Latency.name) != nil) && (viface.voutput.get_property(Resource::Latency.name).delay != nil)
          bw_input = (viface.vinput != nil) && (viface.vinput.get_property(Resource::Bandwidth.name) != nil) && (viface.vinput.get_property(Resource::Bandwidth.name).rate != nil)
          lat_input = (viface.vinput != nil) && (viface.vinput.get_property(Resource::Latency.name) != nil) && (viface.vinput.get_property(Resource::Latency.name).delay != nil)

          clean(viface) if (bw_output != @limited_bw_output) ||
            (lat_output != @limited_lat_output) ||
            (bw_input != @limited_bw_input) ||
            (lat_input != @limited_lat_input) ||
            viface.latency_filters
        end

        # Clean every previous run config
        def clean(viface)
          @limited_bw_output = false
          @limited_lat_output = false
          @limited_bw_input = false
          @limited_lat_input = false
          @@lock.synchronize {
            @@store[viface] = {}
          }

          iface = Lib::NetTools::get_iface_name(viface.vnode,viface)
          ifb = viface.ifb

          str = Lib::Shell.run("tc qdisc show || true").split(/\n/).grep(/ dev #{ifb} /)
          if not str.empty? and not str[0].include?('pfifo_fast')
            inputroot = TCWrapper::QdiscRoot.new(ifb)
            Lib::Shell.run(inputroot.get_cmd(TCWrapper::Action::DEL))
          end

          str = Lib::Shell.run("tc qdisc show | grep #{iface} | grep ingress || true")
          if str and !str.empty?
            inputroot = TCWrapper::QdiscIngress.new(iface)
            Lib::Shell.run(inputroot.get_cmd(TCWrapper::Action::DEL))
          end

          @@ifballocator.free_ifb(ifb)

          str = Lib::Shell.run("tc qdisc show | grep #{iface}")
          if str and !str.empty? and !str.include?('pfifo_fast')
            outputroot = TCWrapper::QdiscRoot.new(iface)
            Lib::Shell.run(outputroot.get_cmd(TCWrapper::Action::DEL))
          end
        end
      end

    end
  end
end
