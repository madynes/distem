$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'
require 'pp'

IMAGE='file:///home/lsarzyniec/rootfs.tar.bz2'


machines = ['chinqchint-1','chinqchint-10','chinqchint-31']

coord = machines[0]
networks = ['network1', 'network2']


i = 1
nodes = []
client = Distem::NetAPI::Client.new(coord)

#Physical node init
machines.each do |machine|
  pp client.pnode_init!(machine)
end
ret = {}
puts 'Waiting for the PNodes to init ...'
machines.each do |machine|
  begin
    ret = client.pnode_info(machine)
    sleep(0.2)
  end until ret['status'] == Wrekavoc::Resource::Status::RUNNING
  puts "\t#{machine} OK"
end
puts 'done'

node = ''
machine = ''
block = Proc.new {
  pp client.vnode_create!(node, { 'image' => IMAGE, 'target' => machine })
}

machine = machines[0]
node = 'node1'
block.call
nodes << node
node = 'node2'
block.call
nodes << node
machine = machines[1]
node = 'node3'
block.call
nodes << node
node = 'node4'
block.call
nodes << node
machine = machines[2]
node = 'node5'
block.call
nodes << node
node = 'node6'
block.call
nodes << node

pp client.vnetwork_create('net1','10.144.1.0/24')
nodes.each do |node|
  pp client.viface_create(node, 'if0')
  pp client.viface_attach(node,'if0', { 'vnetwork' => 'net1' })
end

nodes.shuffle!
puts 'Waiting for the VNodes to be installed ...'
nodes.each do |node|
  begin
    ret = client.vnode_info(node)
    sleep(0.2)
  end until ret['status'] == Wrekavoc::Resource::Status::READY
  puts "\t#{node} OK"
end
puts 'done'

nodes.shuffle!
nodes.each do |node|
  pp client.vnode_start!(node)
end
puts 'Starting the VNodes ...'
nodes.each do |node|
  begin
    ret = client.vnode_info(node)
    sleep(0.2)
  end until ret['status'] == Wrekavoc::Resource::Status::RUNNING
  puts "\t#{node} OK"
end
puts 'done'

nodes.shuffle!
nodes.each do |node|
  pp client.vnode_stop!(node)
end
puts 'Stoping the VNodes ...'
nodes.each do |node|
  begin
    ret = client.vnode_info(node)
    sleep(0.2)
  end until ret['status'] == Wrekavoc::Resource::Status::READY
  puts "\t#{node} OK"
end
puts 'done'
