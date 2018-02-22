#!/usr/bin/ruby

require 'distem'

VNODE = ARGV[0].split(',')
WAY = ARGV[1]
REPETS = 3

puts '<<< Bandwidth test >>>'

def run_exp(band, ip)
  ret = true
  Open3.popen3("distem --execute vnode=node1,command=\"iperf -s -y c -P #{REPETS}\"") do |i,o,e,w|
    sleep 1  # wait 1 second for iperf-server to start
    REPETS.times { |i|  # repeat the measurement repets time
      `distem --execute vnode=node2,command="iperf -t 10 -y c -c #{ip[0]}"`
    }
    data = o.read
    data.each_line do |l|
      puts l
    end
  end
  return ret
end

node1, node2 = VNODE[0..1]
error = false
ifnet = {}
Distem.client do |cl|
  bands2 = [ 512, 1024 ] # in kbit
  bands2.each { |band|
    if WAY == 'input'
      ifnet['input'] = { 'bandwidth' => {'rate' => "#{band}kbit"} }
      cl.viface_update node1, 'if0', ifnet
    else
      ifnet['output'] = { 'bandwidth' => {'rate' => "#{band}kbit"} }
      cl.viface_update node2, 'if0', ifnet
    end

    ip, _ = cl.viface_info(node1, 'if0')['address'].split('/')
    if not run_exp(band, ip)
      error = true
      break
    end
  }
  bands = [ 10, 50, 100, 500, 900 ]  # this is in megabits/s
  if not error
    bands.each { |band|
      if WAY == 'input'
        ifnet['input'] = { 'bandwidth' => {'rate' => "#{band}mbit"} }
        cl.viface_update node1, 'if0', ifnet
      else
        ifnet['output'] = { 'bandwidth' => {'rate' => "#{band}mbit"} }
        cl.viface_update node2, 'if0', ifnet
      end

      if not run_exp(band, ip)
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
