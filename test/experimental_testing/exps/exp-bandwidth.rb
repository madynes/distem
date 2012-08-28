#!/usr/bin/ruby

require 'distem'
require File.join(File.dirname(__FILE__), 'stats')
require File.join(File.dirname(__FILE__), 'helpers')

ERROR = ARGV[0].to_f / 100
IPFILE = '/tmp/ip'
REPETS = 5

puts '<<< Bandwidth test >>>'

ip = IO.readlines(IPFILE).collect { |line| line.strip }

def run_exp(band, f, ip)
  ret = true

  run_and_wait('distem --execute vnode=node1,command="iperf -s -P #{REPETS}"') do 
    sleep 1  # wait 1 second for iperf-server to start
    nums = Stats.new
    REPETS.times {  # repeat the measurement repets time
      data = `distem --execute vnode=node2,command="iperf -t 2 -y c -c #{ip[0]}"`
      result = data.split(',').last.to_f / 1e6
      nums.push result
    }

    if ((nums.mean) > ((1 + ERROR) * band / f)) || ((nums.mean) < ((1 - ERROR) * band / f))
      puts "ERROR: requested #{band / f}mbits, measured #{nums.mean}mbits"
      ret = false
    end
  end
  return ret
end

error = false
Distem.client do |cl|
  
  cl.reset_emulation
  
  bands2 = [ 56, 128, 256, 512, 768, 1024 ]
  bands2.each { |band|
    ifnet = { 'input' => {}, 'output' => {} }
    cl.viface_update 'node2', 'af0', ifnet

    ifnet['input'] = { 'bandwidth' => {'rate' => "#{band}kbit"} }
    cl.viface_update 'node1', 'af0', ifnet

    if not run_exp(band, 1000.0, ip)
      error = true
      break
    end
  }
  
  bands = [ 10, 100, 300, 500, 700, 900 ]  # this is in megabits/s
  not error && bands.each { |band|
    ifnet = { 'input' => {}, 'output' => {} }
    cl.viface_update 'node2', 'af0', ifnet
    
    ifnet['input'] = { 'bandwidth' => {'rate' => "#{band}mbit"} }
    cl.viface_update 'node1', 'af0', ifnet
    
    if not run_exp(band, 1.0, ip)
      error = true
      break
    end
  }
end
if error
  puts 'TEST NOT PASSED'
else
  puts 'TEST PASSED'
end
