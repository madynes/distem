$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'
require 'pp'

IMAGE='file:///home/lsarzyniec/rootfs.tar.bz2'


machines = [
'griffon-16.nancy.grid5000.fr',
'griffon-17.nancy.grid5000.fr',
'griffon-18.nancy.grid5000.fr',
]

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
corenb = 0
corefreq = 0.0
block = Proc.new {
  pp client.vnode_create!(node, { 'image' => IMAGE, 'target' => machine })
  pp client.vcpu_create(node,corenb,corefreq)
}

# Physical Machine 0
machine = machines[0]

node = 'node11'
corenb = 5
corefreq = 0.6
block.call
nodes << node

node = 'node12'
corenb = 2
corefreq = 0.2
block.call
nodes << node

node = 'node13'
corenb = 1
corefreq = 0.5
block.call
nodes << node

# Physical Machine 1
machine = machines[1]

node = 'node21'
corenb = 8
corefreq = 0.8
block.call
nodes << node

# Physical Machine 2
machine = machines[2]

node = 'node31'
corenb = 1
corefreq = 0.2
block.call
nodes << node

node = 'node32'
corenb = 1
corefreq = 0.2
block.call
nodes << node

node = 'node33'
corenb = 1
corefreq = 0.4
block.call
nodes << node

node = 'node34'
corenb = 1
corefreq = 0.4
block.call
nodes << node

node = 'node35'
corenb = 1
corefreq = 0.6
block.call
nodes << node

node = 'node36'
corenb = 1
corefreq = 0.6
block.call
nodes << node

node = 'node37'
corenb = 1
corefreq = 0.8
block.call
nodes << node

pp client.vnetwork_create('net1','10.144.1.0/24')
nodes.each do |node|
  pp client.viface_create(node, 'if0')
  pp client.viface_attach(node,'if0', { 'vnetwork' => 'net1' })
end

puts 'Waiting for the VNodes to be installed ...'
nodes.each do |node|
  begin
    ret = client.vnode_info(node)
    sleep(1)
  end until ret['status'] == Wrekavoc::Resource::Status::READY
  puts "\t#{node} OK"
end
puts 'done'

nodes.shuffle!
nodes.each do |node|
  pp client.vnode_start(node)
end
puts 'Starting the VNodes ...'
nodes.each do |node|
  begin
    ret = client.vnode_info(node)
    sleep(1)
  end until ret['status'] == Wrekavoc::Resource::Status::RUNNING
  puts "\t#{node} OK"
end
puts 'done'
