$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'
require 'pp'

IMAGE='file:///home/lsarzyniec/rootfs.tar.bz2'

machines = ['griffon-90']

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

pp client.vnetwork_create('net1','10.144.1.0/24')
node = 'testnode'
pp client.vnode_create(node, { 'image' => IMAGE })
pp client.viface_create(node, 'if0')
pp client.viface_attach(node,'if0', { 'vnetwork' => 'net1' })
pp client.vcpu_create(node,3,1000)
pp client.vnode_start(node)
