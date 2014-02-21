#!/usr/bin/ruby


# Import the Distem module
require 'distem'
require 'socket'

net,netmask = ARGV[0].split('/')
ip_file = ARGV[1]
image = ARGV[2]

nodes = (1..50).to_a.map { |i| "node#{i}" }
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
  iplist.each { |ip| exit 1 if not wait_ssh(ip, 300) }

  File.open(ip_file,'w') do |f|
    iplist.each{ |ip| f.puts(ip) }
  end
}
