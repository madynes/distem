$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'

IMAGE='file:///home/lsarzyniec/rootfs.tar.bz2'


machines = ['griffon-9.nancy.grid5000.fr','griffon-87.nancy.grid5000.fr','griffon-88.nancy.grid5000.fr','griffon-89.nancy.grid5000.fr','griffon-92.nancy.grid5000.fr']

coord = 'griffon-9.nancy.grid5000.fr'
networks = {}
networks['net1'] = '10.144.1.0/24'
networks['net2'] = '10.144.2.0/24'
networks['net3'] = '10.144.3.0/24'
networks['net4'] = '10.144.4.0/24'
networks['net5'] = '10.144.5.0/24'
networks['net6'] = '10.144.6.0/24'


i = 1
nodes = []
client = Distem::NetAPI::Client.new(coord)

networks.each_pair do |net,addr|
  puts client.vnetwork_create(net,addr)
end

machines.each do |machine|
  puts client.pnode_init(machine)
  networks.each_key do |net|
      node = 'node' + i.to_s
      puts client.vnode_create(machine, node, IMAGE)
      puts client.viface_create(node, 'if0')
      puts client.vnetwork_add_vnode(net, node, 'if0')
      nodes << node
      i += 1
  end
end

machine = machines[rand(machines.size)]
node = 'nodegw12'
puts client.vnode_create(machine, node, IMAGE)
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode('net1', node, 'if0')
puts client.viface_create(node, 'if1')
puts client.vnetwork_add_vnode('net2', node, 'if1')
puts client.vroute_create('net1','net2','nodegw12')
puts client.vroute_create('net2','net1','nodegw12')
nodes << node

machine = machines[rand(machines.size)]
node = 'nodegw2345'
puts client.vnode_create(machine, node, IMAGE)
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode('net2', node, 'if0')
puts client.viface_create(node, 'if1')
puts client.vnetwork_add_vnode('net3', node, 'if1')
puts client.viface_create(node, 'if2')
puts client.vnetwork_add_vnode('net4', node, 'if2')
puts client.viface_create(node, 'if3')
puts client.vnetwork_add_vnode('net5', node, 'if3')
puts client.vroute_create('net2','net3','nodegw2345')
puts client.vroute_create('net3','net2','nodegw2345')
puts client.vroute_create('net3','net4','nodegw2345')
puts client.vroute_create('net4','net3','nodegw2345')
puts client.vroute_create('net3','net5','nodegw2345')
puts client.vroute_create('net5','net3','nodegw2345')
nodes << node

machine = machines[rand(machines.size)]
node = 'nodegw56'
puts client.vnode_create(machine, node, IMAGE)
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode('net5', node, 'if0')
puts client.viface_create(node, 'if1')
puts client.vnetwork_add_vnode('net6', node, 'if1')
puts client.vroute_create('net5','net6','nodegw56')
puts client.vroute_create('net6','net5','nodegw56')
nodes << node

puts client.vroute_create('net1','net3','nodegw12')
puts client.vroute_create('net3','net1','nodegw2345')

puts client.vroute_create('net1','net4','nodegw12')
puts client.vroute_create('net4','net1','nodegw2345')

puts client.vroute_create('net1','net5','nodegw12')
puts client.vroute_create('net5','net1','nodegw2345')

puts client.vroute_create('net1','net6','nodegw12')
puts client.vroute_create('net6','net1','nodegw56')

puts client.vroute_create('net2','net4','nodegw2345')
puts client.vroute_create('net4','net2','nodegw2345')

puts client.vroute_create('net2','net5','nodegw2345')
puts client.vroute_create('net5','net2','nodegw2345')

puts client.vroute_create('net2','net6','nodegw2345')
puts client.vroute_create('net6','net2','nodegw56')

puts client.vroute_create('net3','net6','nodegw2345')
puts client.vroute_create('net6','net3','nodegw56')

puts client.vroute_create('net4','net5','nodegw2345')
puts client.vroute_create('net5','net4','nodegw2345')

puts client.vroute_create('net4','net6','nodegw2345')
puts client.vroute_create('net6','net4','nodegw56')

nodes.each do |node|
  puts client.vnode_start(node)
end
