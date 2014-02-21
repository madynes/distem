#!/usr/bin/ruby

require 'distem'
require 'net/ssh'
require 'net/ssh/multi'

def ssh_exec(ssh, command)
  stdout_data = ''
  stderr_data = ''
  exit_code = nil
  exit_signal = nil
  ssh.open_channel do |channel|
    channel.exec(command) do |ch, success|
      unless success
        abort "FAILED: couldn't execute command (ssh.channel.exec)"
      end
      channel.on_data do |ch, data|
        stdout_data += data
      end

      channel.on_extended_data do |ch, type, data|
        stderr_data += data
      end

      channel.on_request("exit-status") do |ch, data|
        exit_code = data.read_long
      end

      channel.on_request("exit-signal") do |ch, data|
        exit_signal = data.read_long
      end
    end
  end
  ssh.loop
  [stdout_data, stderr_data, exit_code, exit_signal]
end

def do_error
  puts 'TEST NOT PASSED'
  exit 1
end

IPFILE = '/tmp/ip'
puts '<<< ARP tables check test >>>'

Distem.client do |cl|
  cl.set_global_arptable
end


ips = IO.readlines(IPFILE).collect { |line| line.strip }
ret = nil

Net::SSH::Multi.start { |session|
  ips.each { |ip| session.use("root@#{ip}") }
  ret = ssh_exec(session, 'arp -n|tail -n +2|wc -l')
  session.loop
  do_error if (ret[2] != 0)
  ret[0].split("\n").each { |i| do_error if (i.to_i < 49) }
}

puts 'TEST PASSED'
