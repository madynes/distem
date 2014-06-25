#!/usr/bin/ruby
#
# Create a platform with 3 networks (asia, europe, us) connected together
# via a 'global' network.
# Inspired from the tutorial's example
# To use with: platform_setup_globalinternet.rb <SUBNET>
# e.g.: platform_setup_globalinternet.rb 10.144.0.0/22

require 'distem'
require 'ipaddress'

$cl = Distem::NetAPI::Client.new

def create_subnets
  res_subnet = IPAddress(ARGV[0])
  subnets = res_subnet.split(4)
  $cl.vnetwork_create('global', subnets[0].to_string)
  $cl.vnetwork_create('us', subnets[1].to_string)
  $cl.vnetwork_create('europe', subnets[2].to_string)
  $cl.vnetwork_create('asia', subnets[3].to_string)
  pp $cl.vnetworks_info
end

# The path to the compressed filesystem image
# We can point to local file since our homedir is available from NFS
FSIMG="file:///home/ejeanvoine/public/distem/distem-fs-wheezy.tar.gz"

def create_vnodes
  # Read SSH keys
  private_key = IO.readlines('/root/.ssh/id_rsa').join
  public_key = IO.readlines('/root/.ssh/id_rsa.pub').join
  sshkeys = {
    'private' => private_key,
    'public' => public_key
  }

  $cl.vnode_create('r-us', { 'vfilesystem' => { 'image' => FSIMG } }, sshkeys)
  $cl.vnode_create('r-europe', { 'vfilesystem' => { 'image' => FSIMG } }, sshkeys)
  $cl.vnode_create('r-asia', { 'vfilesystem' => { 'image' => FSIMG } }, sshkeys)
  $cl.vnode_create('us1', { 'vfilesystem' => { 'image' => FSIMG } }, sshkeys)
  $cl.vnode_create('europe1', { 'vfilesystem' => { 'image' => FSIMG } }, sshkeys)
  $cl.vnode_create('asia1', { 'vfilesystem' => { 'image' => FSIMG } }, sshkeys)
end

def create_vifaces
  # routers on global network
  $cl.viface_create('r-us', 'if0', { 'vnetwork' => 'global', "output"=>{ "latency"=> {"delay" => "20ms"} }, "input"=>{ "latency"=> { "delay" => "20ms" } }})
  $cl.viface_create('r-europe', 'if0', { 'vnetwork' => 'global', "output"=>{ "latency"=> {"delay" => "30ms" } }, "input"=>{ "latency"=>{ "delay" =>  "30ms" } } })
  $cl.viface_create('r-asia', 'if0', { 'vnetwork' => 'global', "output"=>{ "latency"=> { "delay" => "40ms" } }, "input"=>{ "latency"=> { "delay" => "40ms" } } })

  # routers on their respective local networks
  $cl.viface_create('r-us', 'if1', { 'vnetwork' => 'us' })
  $cl.viface_create('r-europe', 'if1', { 'vnetwork' => 'europe' })
  $cl.viface_create('r-asia', 'if1', { 'vnetwork' => 'asia' })

  # nodes on local networks
  $cl.viface_create('us1', 'if0', { 'vnetwork' => 'us' })
  $cl.viface_create('europe1', 'if0', { 'vnetwork' => 'europe' })
  $cl.viface_create('asia1', 'if0', { 'vnetwork' => 'asia' })
end

def create_vroutes
  $cl.vroute_complete
end



create_subnets
create_vnodes
create_vifaces
create_vroutes

# start all vnodes
$cl.vnodes_start($cl.vnodes_info.map { |vn| vn['name'] })
$cl.set_global_etchosts

pp $cl.vnodes_info

exit(0)
