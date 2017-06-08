
module Distem
  module Algorithm
    module Network

      # A common interface for TC based algorithms
      class TCAlgorithm < Algorithm

        @@lock = Mutex.new
        @@store = {}
        @@ifballocator = nil

        def initialize()
          @limited_netem_output = false
          @limited_netem_input = false
          if @@ifballocator.nil?
            @@ifballocator = Node::IFBAllocator::new
          end
        end

        # :nodoc:
        def apply(viface)
          @@lock.synchronize {
            @@store[viface] = {} if !@@store[viface]
          }

          netem_output = (viface.voutput != nil) && viface.voutput.limited?
          netem_input = (viface.vinput != nil) && viface.vinput.limited?

          clean(viface) if (netem_input != @limited_netem_input) ||
            (netem_output != @limited_netem_output) ||
            viface.latency_filters
        end

        # Clean every previous run config
        def clean(viface)
          @limited_netem_output = false
          @limited_netem_input = false
          @@lock.synchronize {
            @@store[viface] = {}
          }

          iface = Lib::NetTools::get_iface_name(viface)
          ifb = viface.ifb

          str = Lib::Shell.run("tc qdisc show || true").split(/\n/).grep(/ dev #{ifb} /)
          if not str.empty? and (not str[0].include?('pfifo_fast') and not str[0].include?('noqueue'))
            inputroot = TCWrapper::QdiscRoot.new(ifb)
            Lib::Shell.run(inputroot.get_cmd(TCWrapper::Action::DEL))
          end

          str = Lib::Shell.run("tc qdisc show | grep \" #{iface} \"| grep ingress || true")
          if str and !str.empty?
            inputroot = TCWrapper::QdiscIngress.new(iface)
            Lib::Shell.run(inputroot.get_cmd(TCWrapper::Action::DEL))
          end

          @@ifballocator.free_ifb(ifb)

          str = Lib::Shell.run("tc qdisc show | grep \" #{iface} \"")
          if str and not str.empty? and ( not str.include?('pfifo_fast') and not str.include?('noqueue'))
            outputroot = TCWrapper::QdiscRoot.new(iface)
            Lib::Shell.run(outputroot.get_cmd(TCWrapper::Action::DEL))
          end
        end
      end

    end
  end
end
