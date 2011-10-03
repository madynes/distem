require 'distem'
require 'net/ssh'

module Distem
  module Daemon

    # Class that allow to manage daemon administration methods such as initializing another physical node
    class Admin
      # The file used to store the stdout and stderr logs for the launched daemons
      PATH_DISTEMD_LOG=File.join(Lib::FileManager::PATH_DISTEM_LOGS,"distemd.log")
      # Paths to the SSH key files
      PATH_SSH_KEYS=['/root/.ssh/id_rsa','/root/.ssh/id_dsa']

      # Run a daemon on a distant server (physical node)
      # ==== Attributes
      # * +pnode+ The PNode object
      #
      def self.pnode_run_server(pnode)
        raise unless pnode.is_a?(Resource::PNode)

        if pnode.status == Resource::Status::INIT
          begin
            Net::SSH.start(pnode.address.to_s, pnode.ssh_user, :keys => PATH_SSH_KEYS, :password => pnode.ssh_password) do |ssh|
              ssh.exec!("mkdir -p #{Lib::FileManager::PATH_DISTEM_LOGS}")
              ssh.exec!("echo '' > #{Lib::Shell::PATH_DISTEMD_LOG_CMD}")

              str = ssh.exec!("lsof -Pnl -i4")
              unless /^distemd .*/.match(str)
                ssh.exec!("distemd &>#{PATH_DISTEMD_LOG} &")

                retries = 20
                cl = NetAPI::Client.new(pnode.address)
                begin
                  cl.pnode_info()
                rescue Lib::UnavailableResourceError
                  sleep(0.2)
                  retries -= 1
                  retry if retries >= 0
                end
              end
            end
          rescue Net::SSH::AuthenticationFailed, Errno::ENETUNREACH
            raise Lib::UnreachableResourceError, pnode.address.to_s
          end
        end
      end

      # Execute a specific command on a (runned) virtual node using ssh
      # ==== Attributes
      # * +vnode+ The VNode object
      # * +command+ The command (String)
      #
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

      # Get the address to use on a virtual network for the ssh tasks (the last address of each virtual network is allocated to the main daemon to contact the virtual nodes (i.e. to use vnode_run)
      # ==== Attributes
      # * +vnetwork+ The VNetwork object
      #
      def self.get_vnetwork_addr(vnetwork)
        vnetwork.address.last.to_string
      end
    end

  end

end
