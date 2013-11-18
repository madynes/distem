#!/usr/bin/ruby


# Import the Distem module
require 'distem'
require 'socket'

net,netmask = ARGV[0].split('/')
ip_file = ARGV[1]
image = ARGV[2]

nodes = (1..200).to_a.map { |i| "node#{i}" }
iplist = []

Distem.client { |cl|
  cl.vnetwork_create('vnet', "#{net}/#{netmask}")
  res = cl.vnodes_create(nodes,
                        {
                          'vfilesystem' =>{'image' => image, 'shared' => true},
                          'vifaces' => [{'name' => 'af0', 'vnetwork' => 'vnet'}]
                        })
  res.each { |r| iplist << r['vifaces'][0]['address'].split('/')[0] }

  # Start the virtual nodes
  puts "Starting the nodes"
  cl.vnodes_start(nodes)

  puts "Checking if the nodes are up"
  ret = cl.wait_vnodes({'timeout' => 600, 'vnodes'=>nodes, 'port' => 22})
  if ret
    File.open(ip_file,'w') do |f|
      iplist.each{ |ip| f.puts(ip) }
    end
  else
    puts "Vnodes are unreachable"
    exit 1
  end
}
