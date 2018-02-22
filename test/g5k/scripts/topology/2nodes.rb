#!/usr/bin/ruby

require 'distem'

pnode1, pnode2 = ARGV[0].split(',')[0..1]
net,netmask = ARGV[1].split('/')
image = ARGV[2]

Distem.client do |cl|
  cl.vnetwork_create('vnet', "#{net}/#{netmask}")
  cl.vnode_create('node1',
                  {
                    'host' => pnode1,
                    'vfilesystem' =>{'image' => image, 'shared' => true},
                    'vifaces' => [{'name' => 'if0', 'vnetwork' => 'vnet', 'default' => true}]
                  })
  cl.vnode_create('node2',
                  {
                    'host' => pnode2,
                    'vfilesystem' =>{'image' => image, 'shared' => true},
                    'vifaces' => [{'name' => 'if0', 'vnetwork' => 'vnet', 'default' => true}]
                  })
  puts("Starting vnodes to be here")
  cl.vnodes_start(['node1', 'node2'])
  sleep(10)
  puts "Checking if the nodes is up"
  ret = cl.wait_vnodes({'timeout' => 180, 'port' => 22})
  cl.set_global_etchosts
  if ret
    exit 0
  else
    exit 1
  end
end
