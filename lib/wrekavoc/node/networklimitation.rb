require 'wrekavoc'

module Wrekavoc
  module Node

    class NetworkLimitation
      def self.apply(limitation)
        #case limitation.algorithm
        #  when Limitation::Network::Algorithm::TBF
            apply_tbf(limitation)
        #  when Limitation::Network::Algorithm::HTB
        #    apply_htb(limitation)
        #  else
        #    apply_tbf(limitation)
        #end
      end

      def self.apply_tbf(limitation)
        iface = Lib::NetTools::get_iface_name(limitation.vnode,limitation.viface)
        tcroot = TCWrapper::QdiscRoot.new(iface)
        tmproot = tcroot

        bwlim = limitation.get_property(Limitation::Network::Property::Type::BANDWIDTH)
        if bwlim
          tmproot = TCWrapper::QdiscTBF.new(iface,tmproot, \
              { 'rate' => "#{bwlim.rate}", 'buffer' => 1800, \
                'latency' => '50ms'})
          Lib::Shell.run(tmproot.get_cmd(TCWrapper::Action::ADD))
        end

        latlim = limitation.get_property(Limitation::Network::Property::Type::LATENCY)
        if latlim
          tmproot = TCWrapper::QdiscNetem.new(iface,tmproot, \
            {'delay' => "#{latlim.delay}"})
          Lib::Shell.run(tmproot.get_cmd(TCWrapper::Action::ADD))
        end

      end

      def self.apply_htb(limitation)
      end
    end

  end
end
