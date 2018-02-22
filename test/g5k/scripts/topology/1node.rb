#!/usr/bin/ruby

require 'distem'

pnode1 = ARGV[0].split(',')[0]
net,netmask = ARGV[1].split('/')
image = ARGV[2]

Distem.client do |cl|
  cl.vnetwork_create('vnet', "#{net}/#{netmask}")
  res = cl.vnode_create('node1',
                  {
                    'host' => pnode1,
                    'vfilesystem' =>{'image' => image, 'shared' => true},
                    'vifaces' => [{'name' => 'if0', 'vnetwork' => 'vnet', 'default' => true}]
                  })
  puts("Starting vnode to be here")
  cl.vnode_start('node1')
  sleep(10)
  puts "Checking if the node is up"
  ret = cl.wait_vnodes({'timeout' => 180, 'port' => 22})
  if ret
    exit 0
  else
    exit 1
  end
end
