#!/usr/bin/ruby:

require 'distem'
require File.join(File.dirname(__FILE__), 'stats')
require File.join(File.dirname(__FILE__), 'helpers')

ERROR = ARGV[0].to_f / 100
WAY = ARGV[1]
REPETS = ARGV[2].to_i
IPFILE = '/tmp/ip'

puts '<<< Latency test [ ms ] >>>'

ip = IO.readlines(IPFILE).collect { |line| line.strip }

error = false
Distem.client do |cl|
 `distem --execute vnode=node1,command="killall -KILL python"`
 `distem --execute vnode=node2,command="killall -KILL python"`

  latencies = [5, 10, 20, 50, 100]

  latencies.each { |lat|
    ifnet = {}
    if lat != 0 then
      if WAY == 'input'
        ifnet['input'] = {'latency' => { 'delay' => "#{lat}ms" }}
        ifnet['output'] = {'latency' => { 'delay' => "0ms" }}
      else
        ifnet['output'] = {'latency' => { 'delay' => "#{lat}ms" }}
        ifnet['input'] = {'latency' => { 'delay' => "0ms" }}
      end
    else
      ifnet['input'] = { }
      ifnet['output'] = { }
    end
    if WAY == 'input'
      cl.viface_update 'node2', 'af0', ifnet
    else
      cl.viface_update 'node1', 'af0', ifnet
    end

    # WARM UP
    run_and_wait('distem --execute vnode=node1,command="/opt/latency.py pong"') do
      data =   `distem --execute vnode=node2,command="/opt/latency.py ping #{ip[0]} #{REPETS}"`
    end

    run_and_wait('distem --execute vnode=node1,command="/opt/latency.py pong"') do
      data =   `distem --execute vnode=node2,command="/opt/latency.py ping #{ip[0]} #{REPETS}"`
      data = data.lines.map { |x| x.to_f * 1e3}
      nums = Stats.new(data)
      if (nums.mean > ((1 + ERROR) * lat)) || (nums.mean < ((1 - ERROR) * lat))
        puts "ERROR: requested #{lat}ms, measured #{nums.mean}ms"
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
