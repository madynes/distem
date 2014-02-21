#!/usr/bin/ruby

require 'distem'
require File.join(File.dirname(__FILE__), 'stats')
require File.join(File.dirname(__FILE__), 'helpers')

nb_cpu = ARGV[0].to_i
algo = ARGV[1]
freq = ARGV[2].to_i
error = ARGV[3].to_i
dgemm_ref = ARGV[4].to_f
fft_ref = ARGV[5].to_f
hpl_ref = ARGV[6].to_f

ERROR = error / 100.0
IPFILE = '/tmp/ip'
ITER = 2

ip = IO.readlines(IPFILE).collect { |line| line.strip }


puts "<<< HPCC test #{nb_cpu} cpu, #{algo}, #{freq} Mhz >>>"

pnode = `hostname`.strip
Distem.client { |cl|
  cl.pnode_update(pnode, {"algorithms"=>{"cpu"=>algo}})
  infos = cl.vnode_info('node1')
  fs = infos['vfilesystem']
  ifaces = infos['vifaces']
  cl.vnode_stop('node1')
  cl.vnode_remove('node1')
  cl.vnode_create('node1', {'host' => pnode, 'vfilesystem' => fs, 'vifaces' => ifaces})
  cl.vcpu_create('node1', freq, 'mhz', nb_cpu)
  cl.vnode_start('node1')
  wait_ssh(ip[0])
  cl.vnode_execute('node1','rm -rf /root/hpccoutf.txt')
  ITER.times.each { |i|
    if nb_cpu > 1 then
      cl.vnode_execute('node1', "/usr/bin/mpiexec -np #{nb_cpu} /usr/bin/hpcc")
    else
      cl.vnode_execute('node1', "/usr/bin/hpcc")
    end
  }
}

tmp_file = '/tmp/hpcc_output'
system("rm -fr #{tmp_file}; /usr/bin/distem --copy-from vnode=node1,user=root,src=/root/hpccoutf.txt,dest=#{tmp_file}")

benchs = {
  'hpl' =>
  {
    'str' => 'HPL_Tflops',
    'coef' => 1000,
    'ref' => hpl_ref
  },
  'dgemm' =>
  {
    'str' => 'StarDGEMM_Gflops',
    'coef' => 1,
    'ref' => dgemm_ref
  },
  'fft' =>
  {
    'str' => 'MPIFFT_Gflops',
    'coef' => 1,
    'ref' => fft_ref
  }
}

error = false
benchs.each_key { |key|
  stats = Stats.new
  str = `grep #{benchs[key]['str']} #{tmp_file}`
  str.split("\n").each { |l|
    stats.push(l.split('=')[1].to_f * benchs[key]['coef'])
  }

  if (stats.mean > ((1 + ERROR) * benchs[key]['ref'])) || (stats.mean < ((1 - ERROR) * benchs[key]['ref']))
    puts "ERROR #{key} bench: requested #{benchs[key]['ref']}, measured #{stats.mean}"
    error = true
    break
  end
}

if error
  puts 'TEST NOT PASSED'
else
  puts 'TEST PASSED'
end
