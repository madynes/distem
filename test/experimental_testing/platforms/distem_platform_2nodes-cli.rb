#!/usr/bin/ruby

require 'socket'

net,netmask = ARGV[0].split('/')
pnodes = ARGV[1].split(',')
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

res = system("distem --create-vnetwork vnetwork=vnet,address=#{net}/#{netmask}")
res = res && system("distem --create-vnode vnode=node1,pnode=#{pnodes[0]},rootfs=#{image}")
res = res && system("distem --create-vnode vnode=node2,pnode=#{pnodes[1]},rootfs=#{image}")
res = res && system("distem --create-viface vnode=node1,iface=af0,vnetwork=vnet")
res = res && system("distem --create-viface vnode=node2,iface=af0,vnetwork=vnet")
res = res && system("distem --start-vnode node1")
res = res && system("distem --start-vnode node2")
exit 1 if not res
iplist = [ '10.144.0.1', '10.144.0.2']
sleep(10)
puts "Checking if the nodes are up"
iplist.each { |ip| exit 1 if not wait_ssh(ip, 300) }

File.open(ip_file,'w') do |f|
  iplist.each{ |ip| f.puts(ip) }
end
