$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'
require 'pp'

IMAGE='file:///home/lsarzyniec/rootfs.tar.bz2'


machines = ['griffon-78','griffon-81','griffon-91']
#machines = ['graphene-75','graphene-80','graphene-81']

coord = machines[0]
networks = ['network1', 'network2']


i = 1
nodes = []
client = Distem::NetAPI::Client.new(coord)

pp client.vnetwork_create(networks[0],'10.144.2.0/24')
pp client.vnetwork_create(networks[1],'10.144.3.0/24')

machines.each do |machine|
  pp client.pnode_init(machine)
end

node = 'node1'
machine = machines[0]
ifprops = {
	'vnetwork' => networks[0],
	'vtraffic' => { 
		"OUTPUT" => { 
			"bandwidth" => {"rate" => "20mbps"},
			"latency" => {"delay" => "5ms"}
		},
		"INPUT" => { 
			"bandwidth" => {"rate" => "100mbps"},
			"latency" => {"delay" => "2ms"}
		}
	}
}
pp client.vnode_create(node, { 'image' => IMAGE })
pp client.viface_create(node, 'if0')
pp client.viface_attach(node, 'if0', ifprops)
nodes << node

node = 'node2'
ifprops['network'] = nil
ifprops['address'] = '10.144.3.7'
ifprops['vtraffic']['OUTPUT'] = nil
ifprops['vtraffic']['INPUT'] = nil
ifprops['vtraffic']['FULLDUPLEX'] = { 
	"bandwidth" => {"rate" => "2mbps"},
	"latency" => {"delay" => "50ms"}
}

pp client.vnode_create(node, { 'image' => IMAGE })
pp client.viface_create(node, 'if0')
pp client.viface_attach(node, 'if0', ifprops)
nodes << node

node = 'node3'
machine = machines[1]
pp client.vnode_create(node, { 'image' => IMAGE })
pp client.viface_create(node, 'if0')
pp client.viface_attach(node, 'if0', { 'vnetwork' => networks[0] })
nodes << node

node = 'node4'
machine = machines[2]
pp client.vnode_create(node, { 'image' => IMAGE })
pp client.viface_create(node, 'if0')
pp client.viface_attach(node, 'if0', { 'vnetwork' => networks[1] })
nodes << node

node = 'nodegw'
pp client.vnode_create(node, { 'image' => IMAGE })
pp client.viface_create(node, 'if0')
pp client.viface_attach(node, 'if0', { 'vnetwork' => networks[0] })
pp client.viface_create(node, 'if1')
pp client.viface_attach(node, 'if1', { 'vnetwork' => networks[1] })
nodes << node

pp client.vroute_complete()

nodes.each do |node|
  pp client.vnode_start(node)
end

#pp client.limit_net_create('nodegw','if0','{ "OUTPUT" : { "bandwidth" : {"rate" : "20mbps"}, "latency" : {"delay" : "5ms"} } }')
#pp client.limit_net_create('nodegw','if0','{ "INPUT" : { "bandwidth" : {"rate" : "10mbps"}, "latency" : {"delay" : "15ms"} } }')
#pp client.limit_net_create('nodegw','if1','{ "FULLDUPLEX" : { "bandwidth" : {"rate" : "2mbps"}, "latency" : {"delay" : "50ms"} } }')
