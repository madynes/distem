#!/usr/bin/ruby

require 'distem'
require File.join(File.dirname(__FILE__), 'stats')
require File.join(File.dirname(__FILE__), 'helpers')

ERROR = ARGV[0].to_f / 100
WAY = ARGV[1]
REPETS = ARGV[2].to_i
IPFILE = '/tmp/ip'

puts '<<< Bandwidth test >>>'

ip = IO.readlines(IPFILE).collect { |line| line.strip }

def run_exp(band, f, ip)
  ret = true

  run_and_wait("distem --execute vnode=node1,command=\"iperf -s -P #{REPETS}\"") do
    sleep 1  # wait 1 second for iperf-server to start
    nums = Stats.new
    REPETS.times { |i|  # repeat the measurement repets time
      data = `distem --execute vnode=node2,command="iperf -t 10 -y c -c #{ip[0]}"`
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
ifnet = {}
Distem.client do |cl|
  bands2 = [ 512, 1024 ]
  bands2.each { |band|
    if WAY == 'input'
      ifnet['input'] = { 'bandwidth' => {'rate' => "#{band}kbit"} }
      cl.viface_update 'node1', 'af0', ifnet
    else
      ifnet['output'] = { 'bandwidth' => {'rate' => "#{band}kbit"} }
      cl.viface_update 'node2', 'af0', ifnet
    end

    if not run_exp(band, 1000.0, ip)
      error = true
      break
    end
  }
  bands = [ 10, 50, 100, 500, 900 ]  # this is in megabits/s
  if not error
    bands.each { |band|
      if WAY == 'input'
        ifnet['input'] = { 'bandwidth' => {'rate' => "#{band}mbit"} }
        cl.viface_update 'node1', 'af0', ifnet
      else
        ifnet['output'] = { 'bandwidth' => {'rate' => "#{band}mbit"} }
        cl.viface_update 'node2', 'af0', ifnet
      end

      if not run_exp(band, 1.0, ip)
        error = true
        break
      end
    }
  end
end
if error
  puts 'TEST NOT PASSED'
else
  puts 'TEST PASSED'
end
