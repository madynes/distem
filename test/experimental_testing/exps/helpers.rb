
require 'open3'
require 'socket'
require 'timeout'
require 'tempfile'
require 'distem'
require 'resolv'
require 'set'

class Distem::NetAPI::Client

  def purge_config
    # purges the whole configuration
    for vnode in vnodes_info do
      vnode_stop vnode['name']
    end
    vnodes_remove
    vnetworks_remove
  end

  def reset_emulation
    # assumes interface naming from exp-init
    for vnode in vnodes_info do
      name = vnode['name']
      ifnet = { 'input' => { }, 'output' => { }    }
      viface_update name, 'af0', ifnet
    end
  end

  def vnodes
    return vnodes_info.map { |x| x['name'] }
  end

  def vnodes_start!
    # start vnodes asynchronously and wait for them
    buffer = 500 # start only so many nodes at once
    infos = vnodes_info()
    names = infos.map { |x| x['name'] }
    pending = total = names.length
    names.shuffle!  # every day i'm shuffling...
    for vnodes in names.each_slice(buffer) do
      for name in vnodes do  # start all nodes in this group
        vnode_start! name
      end
      while vnodes.length > 0 do  # wait for all nodes in this group to be running
        vnodes.shuffle!   # i'm shuffling even more...
        puts "#{pending}/#{total} left"
        info = vnode_info(vnodes[-1])
        if info['status'] == 'RUNNING' then
          vnodes.pop()
          pending -= 1
        else
          sleep 1
        end
      end
    end
  end

  def vnodes_start
    for vnode in vnodes_info do
      vnode_start vnode['name']
      print "*"
      STDOUT.flush
    end
    print "\n"
  end

  def wait_for_ssh
    for vnode in vnodes_info do
      addr = vnode['vifaces'][0]['address'].split('/')[0]
      wait_ssh(addr)
    end
  end

  def save_machines
    # save machines to the machines file and returns the path
    File.open(MACHINES_FILE, 'w') do |f|
      for vnode in vnodes_info do
        addr = vnode['vifaces'].first['address'].split('/').first
        f.puts addr
      end
    end
    return MACHINES_FILE
  end

end

def run_and_wait(cmd, &block)
  Open3.popen3(cmd, &block)
end

def port_open?(ip, port)
  # checks if the given ip:port responds
  begin
    s = TCPSocket.new(ip, port)
    s.close
    return true
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
    return false
  end
end

def wait_ssh(host, timeout = 120)
  # waits timeout seconds for SSH to start at host
  def now()
    return Time.now.to_f
  end
  bound = now() + timeout
  while now() < bound do
    t = now()
    return if port_open?(host, 22)
    dt = now() - t
    sleep(0.5 - dt) if dt < 0.5
  end
  raise "SSH did not start on #{host}!"
end

# extremely crazy trick to have perlish dictionaries
# we also inject 'sorted method' that iterates the items
#    in order sorted by keys

def comparator(a, b)
  a, b = a.first, b.first
  a = [ a ] unless a.is_a?(Array)
  b = [ b ] unless b.is_a?(Array)
  a = a.map { |x| x.to_i }
  b = b.map { |x| x.to_i }
  return (a <=> b)
end

class AutoHash < Hash
  def initialize()
    super { 
      |ht, k| ht[k] = AutoHash.new 
    }
  end

  def sorted(&block)
    self.sort { |a, b| comparator(a, b) }.each do |a, b|
      block.call(a, b) if block.nil? == false
    end
  end
end

def measure
  start = Time.now.to_f
  yield
  return (Time.now.to_f - start)
end

def product(*arr)
  # computes cartesian product of the given arrays
  if arr.length == 0
    return [ [] ]
  else
    list = []
    head = arr.first
    rest = product(*arr[1..-1])
    for h in head do
      for p in rest do
        list.push([ h ] + p)
      end
    end
    return list
  end
end

class Table
  def initialize(headers = [ 'x', 'y', 'error' ])
    @rows = { }
    @headers = headers
  end

  def store(key, val)
    key = [ key ] unless key.is_a?(Array)
    key = key.map { |x| x.to_f }
    if @rows.key?(key) then
      @rows[key].push(val.to_f)
    else
      @rows[key] = [ val.to_f ]
    end
  end

  def tostring
    lines = [ ]
    @rows.sort.each do |k, vals|
      s = Stats.new(vals)
      k = k.reduce([]) {|x, y| x + [ sprintf("%.6f", y) ] }.join(' ')
      lines.push(sprintf("%s %.6f %.6f", k, s.mean, s.error))
    end
    return lines.join("\n")
  end

  def show
    puts @headers.join(' ') if @headers
    puts(tostring())
  end
end

class Tables < Hash
  def initialize(headers = [ 'x', 'y', 'error' ])
    super() { |ht, k| 
      ht[k] = Table.new(headers)
    }
  end

  def show_all
    # shows all tables
    self.each { |k, v| 
      puts "# table '#{k}'"
      v.show
      puts
    }
  end
end

def subset?(a, b)
  return Set.new(a).subset?(Set.new(b))
end
