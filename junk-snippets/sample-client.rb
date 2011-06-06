$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'wrekavoc'

IMAGE='file:///home/lsarzyniec/rootfs.tar.bz2'


machines = ['griffon-9.nancy.grid5000.fr','griffon-87.nancy.grid5000.fr','griffon-88.nancy.grid5000.fr','griffon-89.nancy.grid5000.fr','griffon-92.nancy.grid5000.fr']

coord = 'griffon-9.nancy.grid5000.fr'
networks = ['network1', 'network2']


i = 1
nodes = []
client = Wrekavoc::NetAPI::Client.new(coord)

#Physical node init
machines.each do |machine|
  puts client.pnode_init(machine)
end

#VNetworks creation
puts client.vnetwork_create(networks[0],'10.144.2.1/24')
puts client.vnetwork_create(networks[1],'10.144.3.1/24')

#Node 1 creation
node = 'node1'
machine = machines[0]
puts client.vnode_create(machine, node, IMAGE)
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode(networks[0], node, 'if0')
nodes << node

#Node 2 creation
node = 'node2'
puts client.vnode_create(machine, node, IMAGE)
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode(networks[1], node, 'if0')
nodes << node

#Node 3 creation
node = 'node3'
machine = machines[1]
puts client.vnode_create(machine, node, IMAGE)
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode(networks[0], node, 'if0')
nodes << node

#Node 4 creation
node = 'node4'
machine = machines[2]
puts client.vnode_create(machine, node, IMAGE)
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode(networks[1], node, 'if0')
nodes << node

#Node GW creation
node = 'nodegw'
puts client.vnode_create(machine, node, IMAGE)
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode(networks[0], node, 'if0')
puts client.viface_create(node, 'if1')
puts client.vnetwork_add_vnode(networks[1], node, 'if1')
nodes << node

#VRoutes creation
puts client.vroute_complete()

#Starting VNodes
nodes.each do |node|
  puts client.vnode_start(node)
end

#Limitations
puts client.limit_net_create('nodegw','if0','OUTPUT','{ "bandwidth" : {"rate" : "20mbps"}, "latency" : {"delay" : "5ms"} }')
puts client.limit_net_create('nodegw','if0','INPUT','{ "bandwidth" : {"rate" : "10mbps"}, "latency" : {"delay" : "15ms"} }')
puts client.limit_net_create('nodegw','if1','OUTPUT','{ "bandwidth" : {"rate" : "2mbps"}, "latency" : {"delay" : "50ms"} }')
puts client.limit_net_create('nodegw','if1','INPUT','{ "bandwidth" : {"rate" : "4mbps"}, "latency" : {"delay" : "25ms"} }')
