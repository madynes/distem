#!/usr/bin/ruby

require 'distem'
require File.join(File.dirname(__FILE__), 'stats')
require File.join(File.dirname(__FILE__), 'helpers')

ERROR = ARGV[0].to_f / 100
algo = ARGV[1]
max_freq = ARGV[2].to_i

puts "<<< CPU frequency test cpu, #{algo} >>>"

pnode = `hostname`.strip

def run_exp(freq, std_time, max_freq)
  ret = true
  data =  `distem --execute vnode=node1,command="sysbench --max-requests=10000 --test=cpu run |grep avg:"`
  results = data.split[-1][0..-3].to_f
  requested_time = std_time*max_freq/freq
  if (results > ((1 + ERROR) * requested_time)) || (results < ((1 - ERROR) * requested_time))
    puts "ERROR: requested #{requested_time}ms, measured #{results}ms"
    ret = false
  else
    puts "Requested: #{requested_time}ms, measured: #{results}ms"
    puts "#{(1-ERROR)*requested_time} < #{results} < #{(1+ERROR)*requested_time} => OK"
  end
  return ret
end



error = false
Distem.client { |cl|
  cl.pnode_update(pnode, {"algorithms"=>{"cpu"=>algo}})
  infos = cl.vnode_info('node1')
  fs = infos['vfilesystem']
  ifaces = infos['vifaces']
  cl.vnode_stop('node1')
  cl.vnode_remove('node1')
  cl.vnode_create('node1', {'host' => pnode, 'vfilesystem' => fs, 'vifaces' => ifaces})
  cl.vcpu_create('node1', 1, 'ratio', 1)
  cl.vnode_start('node1')
  cl.wait_vnodes({'vnodes' => 'node1'})

  data = `distem --execute vnode=node1,command="sysbench --max-requests=10000 --test=cpu run |grep avg:"`
  ref_time = data.split[-1][0..-3].to_f
  puts "Reference time: #{ref_time}ms"

  10.times { |i|
    f = max_freq * (i + 1) / 10
    cl.vcpu_update('node1', f, 'mhz')
    puts "Update vcpu to #{f} mhz"
    sleep(1)
    if not run_exp(f, ref_time, max_freq)
      error = true
      break
    end
    sleep(1)
  }
}
if error
  puts 'TEST NOT PASSED'
else
  puts 'TEST PASSED'
end
