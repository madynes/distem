#!/usr/bin/ruby

require 'distem'
require File.join(File.dirname(__FILE__), 'stats')
require File.join(File.dirname(__FILE__), 'helpers')

REPETS = 10
ERROR = ARGV[0].to_f / 100
IPFILE = '/tmp/ip'

puts '<<< Latency test [ ms ] >>>'

ip = IO.readlines(IPFILE).collect { |line| line.strip }

error = false
Distem.client do |cl|
  `distem --copy-to vnode=node1,src=~/exps/latency.py,dest=/tmp/latency.py`
  `distem --copy-to vnode=node2,src=~/exps/latency.py,dest=/tmp/latency.py`
  `distem --execute vnode=node1,command="killall -KILL python"`
  `distem --execute vnode=node2,command="killall -KILL python"`

  steps = 3         # no of intermediate steps
  exponents = 3..5  # 10^i   - in microseconds
  latencies = []
  exponents.each{ |exp|
    if exp == exponents.last then
      latencies.push(10 ** exp)
    else
      steps.times { |i|
        latencies.push(10 ** (exp + i / steps.to_f))
      }
    end
  }

  cl.reset_emulation

  latencies.each { |lat|    
    lat = lat.to_i
    ifnet = {}
    if lat != 0 then
      ifnet['output'] = {
        'latency' => { 'delay' => "#{lat}us" }
      }
      ifnet['input'] = {
        'latency' => { 'delay' => "0ms" }
      }
    else
      ifnet['input'] = { }
      ifnet['output'] = { }
    end

    cl.viface_update 'node1', 'af0', ifnet 

    # WARM UP
    run_and_wait('distem --execute vnode=node1,command="/tmp/latency.py pong"') do 
      data =   `distem --execute vnode=node2,command="/tmp/latency.py ping #{ip[0]} #{REPETS}"`
    end

    run_and_wait('distem --execute vnode=node1,command="/tmp/latency.py pong"') do 
      data =   `distem --execute vnode=node2,command="/tmp/latency.py ping #{ip[0]} #{REPETS}"`
      data = data.lines.map { |x| x.to_f * 1e3 }
      nums = Stats.new(data)
      if (nums.mean > ((1 + ERROR) * (lat / 1e3))) || (nums.mean < ((1 - ERROR) * (lat / 1e3)))
        puts "ERROR: requested #{lat / 1e3}ms, measured #{nums.mean}ms"        
        error = true
        break
      end
    end
  }
end
if error
  puts 'TEST NOT PASSED'
else
  puts 'TEST PASSED'
end
