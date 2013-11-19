#!/usr/bin/ruby


# Import the Distem module
require 'distem'
require 'socket'

net,netmask = ARGV[0].split('/')
ip_file = ARGV[1]
image = ARGV[2]

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
  iplist = []
  cl.vnetwork_create('vnet', "#{net}/#{netmask}")
  res = cl.vnode_create('node1', 
                  {
                    'vfilesystem' =>{'image' => image, 'shared' => true},
                    'vifaces' => [{'name' => 'af0', 'vnetwork' => 'vnet'}]
                  })
  iplist << res['vifaces'][0]['address'].split('/')[0]
  cl.vcpu_create('node1', 1, 'ratio', 1)
  cl.vnode_start('node1')
  sleep(10)
  puts "Checking if the node is up"
  exit 1 if not wait_ssh(iplist[0], 300)

  File.open(ip_file,'w') do |f|
    f.puts(iplist[0])
  end
}
