require 'wrekavoc'
require 'net/ssh'

module Wrekavoc
  module Daemon

    class Admin
      PATH_CURRENT=File.expand_path(File.dirname(__FILE__))
      PATH_WREKAVOC_BIN=File.expand_path('../../../bin/',PATH_CURRENT)
      PATH_WREKAVOC_LOGS=File.expand_path('../../../logs/',PATH_CURRENT)
      PATH_WREKAD_LOG_OUT=File.join(PATH_WREKAVOC_LOGS,"wrekad.out")
      PATH_WREKAD_LOG_ERR=File.join(PATH_WREKAVOC_LOGS,"wrekad.err")
      PATH_BIN_RUBY='/usr/bin/ruby'
      PATH_SSH_KEY='/root/.ssh/id_rsa'

      def self.pnode_run_server(pnode)
        raise unless pnode.is_a?(Wrekavoc::Resource::PNode)

        if pnode.status == Wrekavoc::Resource::PNode::STATUS_INIT
          Net::SSH.start(pnode.address, pnode.ssh_user, :keys => PATH_SSH_KEY) do |ssh|
            ssh.exec!("mkdir -p #{PATH_WREKAVOC_LOGS}")

            str = ssh.exec!("lsof -Pnl -i4")
            unless /^wrekad .*/.match(str)
              ssh.exec!("#{PATH_WREKAVOC_BIN}/wrekad 1>#{PATH_WREKAD_LOG_OUT} &>#{PATH_WREKAD_LOG_ERR} &")
            end
          end
          pnode.status = Wrekavoc::Resource::PNode::STATUS_RUN
        end
      end

      def self.vnode_run(vnode,command)
        raise unless vnode.is_a?(Wrekavoc::Resource::VNode)
        raise unless vnode.vifaces[0].is_a?(Wrekavoc::Resource::VIface)
        raise unless vnode.vifaces[0].attached?
        
        ret = ""
        Net::SSH.start(vnode.vifaces[0].address.to_s, "root", :keys => PATH_SSH_KEY) do |ssh|
          ret = ssh.exec!(command)
        end

        return ret
      end

      def self.get_vnetwork_addr(vnetwork)
        vnetwork.address.last.to_string
      end
    end

  end

end
