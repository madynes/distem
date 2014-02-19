#!/usr/bin/ruby

require 'distem'
require File.join(File.dirname(__FILE__), 'stats')
require File.join(File.dirname(__FILE__), 'helpers')

def do_error
  puts 'TEST NOT PASSED'
  exit 1
end

puts '<<< Event framework test >>>'

def is_here(n)
  return system("ping -c 1 -W 1 #{n}")
end



Distem.client do |cl|
  cl.set_global_etchosts
  puts "#Events from a trace"
  cl.event_trace_add({ 'vnodename' => "node1", 'type' => 'vnode' }, 'churn', { 1 => 'down' })
  cl.event_trace_add({ 'vnodename' => "node2", 'type' => 'vnode' }, 'churn', { 10 => 'down' })
  cl.event_trace_add({ 'vnodename' => "node1", 'type' => 'vnode' }, 'churn', { 20 => 'up' })
  cl.event_trace_add({ 'vnodename' => "node2", 'type' => 'vnode' }, 'churn', { 30 => 'up' })
  do_error if (!is_here("node1") or !is_here("node2"))
  start = Time.now.to_i
  cl.event_manager_start
  sleep(5)
  puts "test 1: node1 down, node2 up"
  do_error if (is_here("node1") or !is_here("node2"))
  now = Time.now.to_i
  sleep(15 - now + start) if (now - start) < 15
  puts "test2: node1 down, node2 down"
  do_error if (is_here("node1") or is_here("node2"))
  now = Time.now.to_i
  sleep(25 - now + start) if (now - start) < 25
  puts "test3: node1 up, node2, down"
  do_error if (!is_here("node1") or is_here("node2"))
  now = Time.now.to_i
  sleep(35 - now + start) if (now - start) < 35
  puts "test4: node1 up, node2 up"
  do_error if (!is_here("node1") or !is_here("node2"))
  cl.event_manager_stop

  puts "#Events from event generator"
  generator_node1 = {
    'date' => {
      'distribution' => 'uniform',
      'min' => 1,
      'max' => 30,
    },
    'value' => {
      'distribution' => 'uniform',
      'min' => 20,
      'max' => 50,
    },
  }
  generator_node2 = {
    'date' => {
      'distribution' => 'uniform',
      'min' => 1,
      'max' => 30,
    },
    'value' => {
      'distribution' => 'uniform',
      'min' => 200,
      'max' => 800,
    },
  }
  cl.event_random_add({'vnodename' => "node1", 'type' => 'viface', 'vifacename' => 'af0', 'viface_direction' => 'output'}, 'latency', generator_node1)
  cl.event_random_add({'vnodename' => "node2", 'type' => 'viface', 'vifacename' => 'af0', 'viface_direction' => 'input'}, 'bandwidth', generator_node2)
  cl.event_manager_start
  sleep(35)
  cl.event_manager_stop
end


puts 'TEST PASSED'
