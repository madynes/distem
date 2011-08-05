require 'wrekavoc'
require 'net/ssh'

module Wrekavoc
  module Daemon

    class Admin
      PATH_WREKAD_LOG_OUT=File.join(Lib::FileManager::PATH_WREKAVOC_LOGS,"wrekad.out")
      PATH_WREKAD_LOG_ERR=File.join(Lib::FileManager::PATH_WREKAVOC_LOGS,"wrekad.err")
      PATH_BIN_RUBY='/usr/bin/ruby'
      PATH_SSH_KEYS=['/root/.ssh/id_rsa','/root/.ssh/id_dsa']

      def self.pnode_run_server(pnode)
        raise unless pnode.is_a?(Resource::PNode)

        if pnode.status == Resource::Status::INIT
          begin
            Net::SSH.start(pnode.address.to_s, pnode.ssh_user, :keys => PATH_SSH_KEYS, :password => pnode.ssh_password) do |ssh|
              ssh.exec!("mkdir -p #{Lib::FileManager::PATH_WREKAVOC_LOGS}")
              ssh.exec!("echo '' > #{Lib::Shell::PATH_WREKAD_LOG_CMD}")

              str = ssh.exec!("lsof -Pnl -i4")
              unless /^wrekad .*/.match(str)
              ssh.exec!("#{Lib::FileManager::PATH_WREKAVOC_BIN}/wrekad " \
                "1>#{PATH_WREKAD_LOG_OUT} &>#{PATH_WREKAD_LOG_ERR} &")
              end
            end
          rescue Net::SSH::AuthenticationFailed, Errno::ENETUNREACH
            raise Lib::UnreachableResourceError, pnode.address.to_s
          end
        end
      end

      def self.vnode_run(vnode,command)
        raise unless vnode.is_a?(Resource::VNode)
        raise unless vnode.vifaces[0].is_a?(Resource::VIface)
        raise unless vnode.vifaces[0].attached?
        
        ret = ""
        Net::SSH.start(vnode.vifaces[0].address.to_s, "root", :keys => PATH_SSH_KEYS) do |ssh|
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
