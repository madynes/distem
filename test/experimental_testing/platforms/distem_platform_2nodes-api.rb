#!/usr/bin/ruby


# Import the Distem module
require 'distem'
require 'socket'

net,netmask = ARGV[0].split('/')
pnodes = ARGV[1].split(',')
if pnodes.length == 1
  pnode1 = pnode2 = pnodes[0]
else
  pnode1 = pnodes[0]
  pnode2 = pnodes[1]
end
ip_file = ARGV[2]
image = ARGV[3]

nodes = ['node1', 'node2']
iplist = []

def port_open?(ip, port)
    # checks if the given ip:port responds
    begin
        s = TCPSocket.new(ip, port)
        s.close
        return true
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
        return false
    end
end

def wait_ssh(host, timeout = 120)
    def now()
        return Time.now.to_f
    end
    bound = now() + timeout
    while now() < bound do
        t = now()
        return true if port_open?(host, 22)
        dt = now() - t
        sleep(0.5 - dt) if dt < 0.5
    end
    return false
end

Distem.client { |cl|
  cl.vnetwork_create('vnet', "#{net}/#{netmask}")

  res = cl.vnode_create('node1',
                        {
                          'host' => pnode1,
                          'vfilesystem' =>{'image' => image, 'shared' => true},
                          'vifaces' => [{'name' => 'af0', 'vnetwork' => 'vnet', 'default' => true}]
                        })
  iplist << res['vifaces'][0]['address'].split('/')[0]

  res = cl.vnode_create('node2',
                        {
                          'host' => pnode2,
                          'vfilesystem' =>{'image' => image, 'shared' => true},
                          'vifaces' => [{'name' => 'af0', 'vnetwork' => 'vnet', 'default' => true}]
                        })
  iplist << res['vifaces'][0]['address'].split('/')[0]


  # Start the virtual nodes
  puts "Starting the nodes"
  nodes.each { |node|
    #puts "Starting #{node}"
    cl.vnode_start(node)
  }

  sleep(10)
  puts "Checking if the nodes are up"
    iplist.each { |ip| exit 1 if not wait_ssh(ip, 300) }

  File.open(ip_file,'w') do |f|
    iplist.each{ |ip| f.puts(ip) }
  end
}
