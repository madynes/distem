# -*- mode: ruby -*-
# vi: set ft=ruby :

# Note: to install VirtualBox Guest Additions automatically (required to
# share /vagrant with the host), just add vagrant-vbguest plugin on the host:
# $> vagrant plugin install vagrant-vbguest

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  numNodes = 2
  ipAddrPrefix = "192.168.60.10"
  system "[ ! -e /tmp/sshkey ] && ssh-keygen -t rsa -f /tmp/sshkey -q -N ''"
  names = ["frontend"] + [*(1..numNodes)].map{ |x| ("node" + x.to_s).to_sym}
  names.each_with_index do |nodeName,index|
    config.vm.define nodeName do |node|
      node.vm.box = "debian-jessie"
      node.vm.box_url = "https://atlas.hashicorp.com/debian/boxes/jessie64/versions/8.2.2/providers/virtualbox.box"
      ip_vnode = ipAddrPrefix + index.to_s
      node.vm.network "private_network", ip: ip_vnode
      node.vm.provider :virtualbox do |v|
        v.name = "Compute Node" + index.to_s
        v.customize ["modifyvm", :id, "--memory", 512]
        v.customize ["modifyvm",:id,"--nicpromisc2","allow-all"]
      end
      node.vm.provision :shell, inline: "echo #{nodeName}> /etc/hostname"
      names.each_with_index do |n,i|
        node.vm.provision :shell, inline: "echo #{ipAddrPrefix + i.to_s} #{n}>> /etc/hosts"
      end
      node.vm.provision :shell, inline: "hostname #{nodeName}"
      node.vm.provision "file", source: "/tmp/sshkey", destination: "~/.ssh/id_rsa"
      node.vm.provision "file", source: "/tmp/sshkey.pub", destination: "~/.ssh/id_rsa.pub"
      node.vm.provision :shell, inline: "mkdir -p /root/.ssh"
      node.vm.provision :shell, inline: "cp /home/vagrant/.ssh/id_rsa* /root/.ssh/"
      node.vm.provision :shell, inline: "echo 'Host *\nStrictHostKeyChecking no\nUserKnownHostsFile /dev/null' > /home/vagrant/.ssh/config"
      node.vm.provision :shell, inline: "echo 'Host *\nStrictHostKeyChecking no\nUserKnownHostsFile /dev/null' > /root/.ssh/config"
      node.vm.provision :shell, inline: "cat /root/.ssh/id_rsa.pub > /root/.ssh/authorized_keys"
      node.vm.provision :shell, inline: "DEBIAN_FRONTEND=noninteractive apt-get install -q -y ruby ruby-dev gem"
      node.vm.provision :shell, inline: "gem install net-ssh-multi"
    end
  end
  File.open("machinefile","w") do |f|
    (1..numNodes).each{ |n| f.puts ipAddrPrefix + n.to_s }
  end
end
