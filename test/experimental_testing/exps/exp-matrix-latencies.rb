#!/usr/bin/ruby

require 'distem'
require File.join(File.dirname(__FILE__), 'stats')
require File.join(File.dirname(__FILE__), 'helpers')

REPETS = 3
ERROR = 0.1

def do_error
  puts 'TEST NOT PASSED'
  exit 1
end

puts '<<< Matrix latencies test >>>'

nodes = (1..50).to_a.map { |i| "node#{i}" }
matrix = (1..50).to_a.map { (1..50).to_a.map { 10 + rand(50) }}
random_nodes = []
while random_nodes.length < 5 do
  random_nodes << 1 + rand(50)
  random_nodes = random_nodes.uniq
end
Distem.client do |cl|
  cl.set_global_etchosts
  cl.set_peers_latencies(nodes,matrix)
end
random_nodes.each { |i|
  random_nodes.each { |j|
    if (i != j)
      `distem --execute vnode=node#{i},command="killall -KILL python"`
      `distem --execute vnode=node#{j},command="killall -KILL python"`

      # WARM UP
      run_and_wait("distem --execute vnode=node#{i},command='/opt/latency.py pong'") do
        data = `distem --execute vnode=node#{j},command="/opt/latency.py ping node#{i} #{REPETS}"`
      end

      run_and_wait("distem --execute vnode=node#{i},command='/opt/latency.py pong'") do
        data = `distem --execute vnode=node#{j},command="/opt/latency.py ping node#{i} #{REPETS}"`
        data = data.lines.map { |x| x.to_f * 1e3}
        nums = Stats.new(data)
        lat = matrix[i-1][j-1] + matrix[j-1][i-1]
        if (nums.mean > ((1 + ERROR) * lat)) || (nums.mean < ((1 - ERROR) * lat))
          puts "ERROR: requested #{lat}ms, measured #{nums.mean}ms"
          do_error
        else
          puts "OK: requested #{lat}ms, measured #{nums.mean}ms"
        end
      end
    end
  }
}
puts 'TEST PASSED'
