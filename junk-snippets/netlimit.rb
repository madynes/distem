$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'

IMAGE='file:///home/lsarzyniec/rootfs.tar.bz2'


machine1 = 'graphene-51'
machine2 = 'graphene-52'
coord = machine1


client = Distem::NetAPI::Client.new(coord)

puts client.vnetwork_create('net1','10.144.2.1/24')
puts client.vnetwork_create('net2','10.144.3.1/24')

puts client.pnode_init(machine1)
puts client.vnode_create(machine1, 'node1', IMAGE)
puts client.viface_create('node1', 'if0')
puts client.vnetwork_add_vnode('net1', 'node1', 'if0')

puts client.pnode_init(machine2)
puts client.vnode_create(machine2, 'node2', IMAGE)
puts client.viface_create('node2', 'if0')
puts client.vnetwork_add_vnode('net1', 'node2', 'if0')

puts client.pnode_init(machine2)
puts client.vnode_create(machine2, 'node3', IMAGE)
puts client.viface_create('node3', 'if0')
puts client.vnetwork_add_vnode('net2', 'node3', 'if0')

puts client.vnode_create(machine2, 'nodegw', IMAGE)
puts client.viface_create('nodegw', 'if0')
puts client.vnetwork_add_vnode('net1', 'nodegw', 'if0')
puts client.viface_create('nodegw', 'if1')
puts client.vnetwork_add_vnode('net2', 'nodegw', 'if1')

puts client.vroute_complete()

puts client.vnode_start('node1')
puts client.vnode_start('node2')
puts client.vnode_start('node3')
puts client.vnode_start('nodegw')

puts client.limit_net_create('node1','if0','OUTPUT','{ "bandwidth" : {"rate" : "10mbps"}, "latency" : {"delay" : "10ms"} }')
puts client.limit_net_create('node3','if0','OUTPUT','{ "bandwidth" : {"rate" : "1mbps"}, "latency" : {"delay" : "100ms"} }')
puts client.limit_net_create('nodegw','if0','OUTPUT','{ "bandwidth" : {"rate" : "20mbps"}, "latency" : {"delay" : "5ms"} }')
puts client.limit_net_create('nodegw','if1','OUTPUT','{ "bandwidth" : {"rate" : "2mbps"}, "latency" : {"delay" : "50ms"} }')
