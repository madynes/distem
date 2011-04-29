require 'net/ssh'
require 'wrekavoc/resource/pnode'

module Wrekavoc

  module Daemon

    class Admin
      PATH_WREKAVOC_BIN=File.join(File.dirname(__FILE__), '..', '..', '..', 'bin')
      PATH_BIN_RUBY='/usr/bin/ruby'
      PATH_SSH_KEY='/root/.ssh/id_rsa'

      def initialize
      end

      def pnode_run_server(pnode)
        raise unless pnode.is_a?(Wrekavoc::Resource::PNode)

        if pnode.status == Wrekavoc::Resource::PNode::STATUS_INIT
          Net::SSH.start(pnode.address, pnode.ssh_user, :keys => PATH_SSH_KEY) do |ssh|
            ssh.exec!("#{PATH_BIN_RUBY} -rubygems #{PATH_WREKAVOC_BIN}/wrekad " \
                      "1>/dev/null &>/dev/null &")
          end
          pnode.status = Wrekavoc::Resource::PNode::STATUS_RUN
        end
      end
    end

  end

end
