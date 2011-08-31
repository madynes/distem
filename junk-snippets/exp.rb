$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'
require 'ipaddr'

IMAGE='file:///home/lsarzyniec/rootfs-squeeze.tar.bz2'


machines = ['griffon-5.nancy.grid5000.fr','griffon-11.nancy.grid5000.fr','griffon-12.nancy.grid5000.fr','griffon-13.nancy.grid5000.fr','griffon-14.nancy.grid5000.fr','griffon-40.nancy.grid5000.fr','griffon-42.nancy.grid5000.fr','griffon-60.nancy.grid5000.fr','griffon-61.nancy.grid5000.fr']
coord = 'griffon-5.nancy.grid5000.fr'
ipaddr = IPAddr.new('10.144.4.1')


i=1
client = Distem::NetAPI::Client.new(coord)

machines.each do |machine|
  client.pnode_init(machine)
  (1..10).each do |j|
    name = "node" + i.to_s
    puts client.vnode_create(machine, name, IMAGE)
    puts client.viface_create(machine, name, 'if0', ipaddr.to_s)
    puts client.vnode_start(machine,name)
    
    i += 1
    ipaddr = ipaddr.succ
  end
end
