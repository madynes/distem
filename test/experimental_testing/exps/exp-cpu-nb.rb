#!/usr/bin/ruby

require 'distem'
require File.join(File.dirname(__FILE__), 'stats')
require File.join(File.dirname(__FILE__), 'helpers')

ERROR = ARGV[0].to_f / 100

puts "<<< CPU core number test >>>"

pnode = `hostname`.strip


error = false
Distem.client { |cl|
  infos = cl.vnode_info('node1')
  fs = infos['vfilesystem']
  ifaces = infos['vifaces']
  cl.vnode_stop('node1')
  cl.vnode_remove('node1')
  cl.vnode_create('node1', {'host' => pnode, 'vfilesystem' => fs, 'vifaces' => ifaces})
  cl.vcpu_create('node1', 1, 'ratio', 2)
  cl.vnode_start('node1')
  cl.wait_vnodes({'vnodes' => 'node1'})

  data = `distem --execute vnode=node1,command="sysbench --num-threads=2 --max-requests=10000 --test=cpu run |grep avg:"`
  time_2cores = data.split[-1][0..-3].to_f

  cl.vnode_stop('node1')
  cl.vnode_remove('node1')
  cl.vnode_create('node1', {'host' => pnode, 'vfilesystem' => fs, 'vifaces' => ifaces})
  cl.vcpu_create('node1', 1, 'ratio', 1)
  cl.vnode_start('node1')
  cl.wait_vnodes({'vnodes' => 'node1'})

  data = `distem --execute vnode=node1,command="sysbench --num-threads=2 --max-requests=10000 --test=cpu run |grep avg:"`
  time_1core = data.split[-1][0..-3].to_f

  puts("2 cores time: #{time_2cores}ms, 1 core time: #{time_1core}")

  if (time_1core > ((1 + ERROR) * 2*time_2cores)) || (time_1core < ((1 - ERROR) * 2*time_2cores))
    puts "ERROR: requested #{2*time_2cores}ms, measures #{time_1core}ms"
    error = true
  else
    puts "#{(1-ERROR)*2*time_2cores} < #{time_1core} < #{(1+ERROR)*2*time_2cores} => OK"
  end
}
if error
  puts 'TEST NOT PASSED'
else
  puts 'TEST PASSED'
end
