require 'distem'

module Distem
  module Algorithm 
    module Network

      # A common interface for TC based algorithms
      class TCAlgorithm < Algorithm
        def initialize()
          @limited_output = false
          @limited_input = false
        end

        # :nodoc:
        def apply(viface)
          clean(viface)
        end

        # Clean every previous run config
        def clean(viface)
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
