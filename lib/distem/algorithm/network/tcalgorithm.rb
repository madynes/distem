require 'distem'

module Distem
  module Algorithm 
    module Network

      # A common interface for TC based algorithms
      class TCAlgorithm < Algorithm

        @@lock = Mutex.new
        @@store = {}

        def initialize()
          @limited_bw_output = false
          @limited_lat_output = false
          @limited_bw_input = false
          @limited_lat_input = false
        end

        # :nodoc:
        def apply(viface)
          @@lock.synchronize {
            @@store[viface] = {} if !@@store[viface]
          }

          bw_output = (viface.voutput != nil) && (viface.voutput.get_property(Resource::Bandwidth.name) != nil)
          lat_output = (viface.voutput != nil) && (viface.voutput.get_property(Resource::Latency.name) != nil)
          bw_input = (viface.vinput != nil) && (viface.vinput.get_property(Resource::Bandwidth.name) != nil)
          lat_input = (viface.vinput != nil) && (viface.vinput.get_property(Resource::Latency.name) != nil)
          clean(viface) if (bw_output != @limited_bw_output) ||
            (lat_output != @limited_lat_output) ||
            (bw_input != @limited_bw_input) ||
            (lat_input != @limited_lat_input)
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
          ifb = "ifb#{viface.id}"

          str = Lib::Shell.run("tc qdisc show | grep #{ifb}")
          if str and !str.empty? and !str.include?('pfifo_fast')
            inputroot = TCWrapper::QdiscRoot.new(ifb)
            Lib::Shell.run(inputroot.get_cmd(TCWrapper::Action::DEL))
          end

          str = Lib::Shell.run("tc qdisc show | grep #{iface} | grep ingress")
          if str and !str.empty?
            inputroot = TCWrapper::QdiscIngress.new(iface)
            Lib::Shell.run(inputroot.get_cmd(TCWrapper::Action::DEL))
          end

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
