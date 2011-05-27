require 'wrekavoc'

module TCWrapper

  class TCConfig

    def self.undo_config(vnode,viface)
      iface = Wrekavoc::Lib::NetTools::get_iface_name(vnode,viface)
      tcroot = QdiscRoot.new(iface)
      
      tcroot.get_cmd(Action::DEL)
    end

    def self.perform_config_tbf(vnode, viface, limitations)
      cmdlist = []
      iface = Wrekavoc::Lib::NetTools::get_iface_name(vnode,viface)
      tcroot = QdiscRoot.new(iface)
      cmdlist << tcroot.get_cmd(Action::ADD)
      tmproot = tcroot

      bwlim = Wrekavoc::Limitation::NetworkManager.get_limitation_by_type(limitations, \
        Wrekavoc::Limitation::Network::Type::BANDWIDTH)
      if bwlim
        tmproot = QdiscTBF.new(iface,tmproot, \
            { 'rate' => "#{bwlim.rate}kbps", 'buffer' => 1800, \
              'latency' => '50ms'})
        cmdlist << tmproot.get_cmd(Action::ADD)
      end

      latlim = Wrekavoc::Limitation::NetworkManager.get_limitation_by_type(limitations, \
        Wrekavoc::Limitation::Network::Type::LATENCY)
      if latlim
        tmproot = QdiscNetem.new(iface,tmproot, \
          {'delay' => "#{latlim.delay}ms"})
        cmdlist << tmproot.get_cmd(Action::ADD)
      end
      return cmdlist
    end
  end

end
