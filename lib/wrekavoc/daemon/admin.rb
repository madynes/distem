require 'wrekavoc'
require 'net/ssh'

module Wrekavoc
  module Daemon

    class Admin
      PATH_WREKAD_LOG_OUT=File.join(Lib::FileManager::PATH_WREKAVOC_LOGS,"wrekad.out")
      PATH_WREKAD_LOG_ERR=File.join(Lib::FileManager::PATH_WREKAVOC_LOGS,"wrekad.err")
      PATH_BIN_RUBY='/usr/bin/ruby'
      PATH_SSH_KEY=['/root/.ssh/id_rsa','/root/.ssh/id_dsa']

      def self.pnode_run_server(pnode)
        raise unless pnode.is_a?(Resource::PNode)
        sshkeypath = get_valid_ssh_key()
        raise Lib::MissingResourceError, 'SSH_KEY_FILE' unless sshkeypath
        
        if pnode.status == Resource::PNode::STATUS_INIT
          begin
            Net::SSH.start(pnode.address.to_s, pnode.ssh_user, :keys => sshkeypath, :password => pnode.ssh_password) do |ssh|
              ssh.exec!("mkdir -p #{Lib::FileManager::PATH_WREKAVOC_LOGS}")
              ssh.exec!("echo '' > #{Lib::Shell::PATH_WREKAD_LOG_CMD}")

              str = ssh.exec!("lsof -Pnl -i4")
              unless /^wrekad .*/.match(str)
              ssh.exec!("#{Lib::FileManager::PATH_WREKAVOC_BIN}/wrekad " \
                "1>#{PATH_WREKAD_LOG_OUT} &>#{PATH_WREKAD_LOG_ERR} &")
              end
            end
          rescue Net::SSH::AuthenticationFailed, Errno::ENETUNREACH, Errno::ECONNREFUSED
            raise Lib::UnreachableResourceError, pnode.address.to_s
          end
        end
      end

      def self.vnode_run(vnode,command)
        raise unless vnode.is_a?(Resource::VNode)
        raise unless vnode.vifaces[0].is_a?(Resource::VIface)
        raise unless vnode.vifaces[0].attached?
        
        sshkeypath = get_valid_ssh_key()
        raise Lib::MissingResourceError, 'SSH_KEY_FILE' unless sshkeypath
        ret = ""
        begin
          Net::SSH.start(vnode.vifaces[0].address.to_s, "root", :keys => sshkeypath, :password => 'root') do |ssh|
            ret = ssh.exec!(command)
          end
        rescue Net::SSH::AuthenticationFailed, Errno::ENETUNREACH, Errno::ECONNREFUSED
          raise Lib::UnreachableResourceError, vnode.vifaces[0].address.to_s
        end

        return ret
      end

      def self.get_vnetwork_addr(vnetwork)
        vnetwork.address.last.to_string
      end

      protected
      def self.get_valid_ssh_key
        ret = nil
        PATH_SSH_KEY.each do |filename|
          if File.exist?(filename)
            ret = filename
            break
          end
        end
        return ret
      end
    end

  end

end
