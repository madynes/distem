#!/usr/bin/ruby

require 'distem'
require 'distem/resource/alevingraphviz'
require File.join(File.dirname(__FILE__), 'stats')
require File.join(File.dirname(__FILE__), 'helpers')

def do_error
  puts 'TEST NOT PASSED'
  exit 1
end

puts '<<< Event framework test >>>'

def is_here(n)
  # http://superuser.com/questions/288521/problem-with-ping-open-socket-operation-not-permitted
  return system("ping -c 1 -W 1 #{n}")
end



Distem.client do |cl|


  platform_file = Tempfile.new("topo")
  count = 1
  graph_g = GraphViz.graph( "G" ) do |graph_g|
    vs = graph_g.add_nodes("physwitch", :cpu =>0, :type => "switch")
    cl.pnodes_info.each do |pnode|
      pnode_ip = pnode[0]
      pnode_name = "pnode#{count}"
      gnode = graph_g.add_nodes(pnode_name,:cpu =>1,:ip => pnode_ip,:type => "host")
      graph_g.add_edges( gnode, vs, :bandwidth => 1000000000)
      count+=1
    end

  end
  graph_g.output(:none => platform_file.path)

  cl.load_physical_topo(platform_file.path)
  cl.run_alevin()
  cl.vnodes_start("node1")
  cl.wait_vnodes()
end


puts 'TEST PASSED'
