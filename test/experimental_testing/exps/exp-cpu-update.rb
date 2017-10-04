#!/usr/bin/ruby

require 'distem'
require File.join(File.dirname(__FILE__), 'stats')
require File.join(File.dirname(__FILE__), 'helpers')

nb_cpu = ARGV[0].to_i
algo = ARGV[1]
max_freq = ARGV[2].to_i

puts "<<< Update CPU frequency test #{nb_cpu} cpu, #{algo} >>>"

pnode = `hostname`.strip

begin
  Distem.client { |cl|
    cl.pnode_update(pnode, {"algorithms"=>{"cpu"=>algo}})
    infos = cl.vnode_info('node1')
    fs = infos['vfilesystem']
    ifaces = infos['vifaces']
    cl.vnode_stop('node1')
    cl.vnode_remove('node1')
    cl.vnode_create('node1', {'host' => pnode, 'vfilesystem' => fs, 'vifaces' => ifaces})
    cl.vcpu_create('node1', 1, 'ratio', nb_cpu)
    cl.vnode_start('node1')
    cl.wait_vnodes({'vnodes' => 'node1'})

    puts "Update CPU using ratio"
    10.times { |i|
      puts "* ratio #{(i + 1.0) / 10}"
      cl.vcpu_update('node1', (i + 1.0) / 10, 'ratio')
      sleep(1)
    }
    puts "Update CPU using frequency"
    10.times { |i|
      puts "* freq #{(max_freq * (i + 1) / 10)}"
      cl.vcpu_update('node1', (max_freq * (i + 1) / 10), 'mhz')
      sleep(1)
    }
  }
  puts 'TEST PASSED'
rescue
  puts 'TEST NOT PASSED'
end
