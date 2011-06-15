$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'wrekavoc'

IMAGE='file:///home/lsarzyniec/rootfs.tar.bz2'


machines = ['graphene-9','graphene-90','graphene-96']

coord = 'graphene-9'
networks = ['network1', 'network2']


i = 1
nodes = []
client = Wrekavoc::NetAPI::Client.new(coord)

puts client.vnetwork_create(networks[0],'10.144.2.1/24')
puts client.vnetwork_create(networks[1],'10.144.2.2/24')

machines.each do |machine|
  puts client.pnode_init(machine)
end

node = 'node1'
machine = machines[0]
puts client.vnode_create(node, { 'image' => IMAGE })
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode(networks[0], node, 'if0')
nodes << node

node = 'node2'
puts client.vnode_create(node, { 'image' => IMAGE })
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode(networks[1], node, 'if0')
nodes << node

node = 'node3'
machine = machines[1]
puts client.vnode_create(node, { 'image' => IMAGE })
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode(networks[0], node, 'if0')
nodes << node

node = 'node4'
machine = machines[2]
puts client.vnode_create(node, { 'image' => IMAGE })
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode(networks[1], node, 'if0')
nodes << node

node = 'nodegw'
puts client.vnode_create(node, { 'image' => IMAGE })
puts client.viface_create(node, 'if0')
puts client.vnetwork_add_vnode(networks[0], node, 'if0')
puts client.viface_create(node, 'if1')
puts client.vnetwork_add_vnode(networks[1], node, 'if1')
nodes << node

puts client.vroute_complete()

nodes.each do |node|
  puts client.vnode_start(node)
end

puts client.limit_net_create('nodegw','if0','{ "OUTPUT" : { "bandwidth" : {"rate" : "20mbps"}, "latency" : {"delay" : "5ms"} } }')
puts client.limit_net_create('nodegw','if0','{ "INPUT" : { "bandwidth" : {"rate" : "10mbps"}, "latency" : {"delay" : "15ms"} } }')
puts client.limit_net_create('nodegw','if1','{ "FULLDUPLEX" : { "bandwidth" : {"rate" : "2mbps"}, "latency" : {"delay" : "50ms"} } }')
