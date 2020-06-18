require_relative 'common_tools'
require_relative 'distem_tools'
require 'minitest/autorun'

MIN_PNODES = 2

if ARGV.length < 4
  CommonTools.error("Usage: #{$PROGRAM_NAME} BOOTSTRAP_PATH TEST_FOLDER" \
                    ' IMAGE_PATH GIT_ADDR [PNODES] [NETWORK]')
end
BOOTSTRAP = ARGV[0] # Bootstrap used by frontend to install distem
TEST_LOCATION = ARGV[1] # Folder containing platforms, exps
IMAGE = ARGV[2] # Image location
GIT = ARGV[3] # Address of the git project
pnodes = ARGV[4] ? ARGV[4].split(',') : nil
network = ARGV[5] ? ARGV[5].split('/') : nil
unless pnodes && network
  if ENV.key?('OAR_JOB_ID')
    pnodes = IO.readlines(ENV.fetch('OAR_NODE_FILE')).collect(&:strip).uniq
    network = `g5k-subnets -p`.strip.split('/')
  else
    CommonTools.error('Must be run inside an OAR reservation or the nodes' \
                      ' and subnet must be set')
  end
end
PNODES = pnodes
NETWORK = network

CommonTools.error('Not enough nodes') if PNODES.length < MIN_PNODES

class NetworkTesting < MiniTest::Test
  @@pnodes = PNODES
  @@initialized = false
  @@launched = false
  @@coordinator = nil
  @@network_config

  def install_distem(adm=false)
    @@coordinator = @@pnodes[0]
    CommonTools.msg('Installing Distem')
    DistemTools.install_distem(@@pnodes, BOOTSTRAP, git_url: GIT,
                               coord: @@coordinator, adm: adm)
    @@launched = true
  end

  def setup
    @@coordinator = @@pnodes[0]
    CommonTools.msg('Setting up Distem')
    DistemTools.prepare_coordinator(TEST_LOCATION, @@coordinator) unless @@initialized
    DistemTools.prepare_pnodes(IMAGE, @@pnodes) unless @@initialized

  end

  def teardown
    CommonTools.msg('Quiting Distem')
    DistemTools.quit_distem if @@launched
    @@launched = false
    @@coordinator = nil
  end

  def test_transfert
    CommonTools.msg "## Starting simple transfert test"
    install_distem
    DistemTools.deploy_topology('2nodes', @@pnodes, NETWORK)
    cmd ='dd if=/dev/urandom of=file bs=1M count=100'
    DistemTools.vnode_execute('node1', cmd)
    src_hash = DistemTools.vnode_execute('node1', 'md5sum file')
    cmd = 'scp -o StrictHostKeyChecking=no file root@node2-vnet:'
    DistemTools.vnode_execute('node1', cmd)
    dst_hash = DistemTools.vnode_execute('node2', 'md5sum file')
    assert_equal src_hash, dst_hash
  end

  def test_transfert_vxlan
    CommonTools.msg "## Starting vxlan transfert test"
    install_distem
    DistemTools.deploy_topology('2nodes_vxlan', @@pnodes, NETWORK)
    sleep 20
    cmd ='dd if=/dev/urandom of=file bs=1M count=100'
    DistemTools.vnode_execute('node1', cmd)
    src_hash = DistemTools.vnode_execute('node1', 'md5sum file')
    cmd = 'scp -o StrictHostKeyChecking=no file root@node2-vnet:'
    DistemTools.vnode_execute('node1', cmd)
    dst_hash = DistemTools.vnode_execute('node2', 'md5sum file')
    assert_equal src_hash, dst_hash
  end

  def test_loss
    CommonTools.msg('Running loss test')
    install_distem(adm=true)
    DistemTools.deploy_topology('2nodes', @@pnodes, NETWORK)
    [10, 25, 50].each do |v|
      cmd = "distem --config-viface vnode=node2,iface=if0,loss=#{v}%,direction=OUTPUT"
      DistemTools.coordinator_execute(cmd)
      ping_cmd = 'ping -f -c 1000 -v node2-vnet | grep loss'
      ref = DistemTools.vnode_execute('node1', ping_cmd).match(/\d{1,3}%/)[0]
      error = (v-ref.to_i).abs
      puts "ref: #{v}%, measured: #{ref}"
      assert error < 4
    end
  end

  def test_latency
    CommonTools.msg('Running latency test')
    install_distem(adm=true)
    DistemTools.deploy_topology('2nodes', @@pnodes, NETWORK)
    ping_cmd = 'ping -f -v -c 100 node2-vnet | grep round | cut -d"/" -f 5' #Get mean time
    ref = DistemTools.vnode_execute('node1', ping_cmd).to_f
    ref = 0.0
    [500, 1000, 2500].each do |v|
      cmd = "distem --config-viface vnode=node1,iface=if0,latency=#{v}ms,direction=OUTPUT"
      DistemTools.coordinator_execute(cmd)
      res =  DistemTools.vnode_execute('node1', ping_cmd).to_f
      error = 100 * ((res - v ).abs / v)
      puts "ref:#{v}ms measured:#{res}ms (err: #{error.to_i}%)"
      assert error < 10
    end
  end

  def test_bandwidth
    CommonTools.msg('Running bandwidth test')
    install_distem(adm=true)
    DistemTools.deploy_topology('2nodes', @@pnodes, NETWORK)
    ping_cmd = 'ping -f -v -c 100 -s 1472 node2-vnet | grep round | cut -d"/" -f 5' #Get mean time
    ref = DistemTools.vnode_execute('node1', ping_cmd).to_f
    [250, 500, 1000, 2500].each do |v|
      cmd = "distem --config-viface vnode=node1,iface=if0,bw=#{v}kbps,direction=OUTPUT"
      DistemTools.coordinator_execute(cmd)
      t =  DistemTools.vnode_execute('node1', ping_cmd).to_f
      res = 1500 / (t - ref)
      error = 100 * ((res - v ).abs / v)
      puts "#For output ref:#{v}kbps, measured:#{res.to_i}kbps (Err: #{error}%)"
      assert error < 20
    end
    cmd = "distem --config-viface vnode=node1,iface=if0,bw=unlimited,direction=OUTPUT"
    DistemTools.coordinator_execute(cmd)
    [250, 500, 1000, 2500].each do |v|
      cmd = "distem --config-viface vnode=node1,iface=if0,bw=#{v}kbps,direction=INPUT"
      DistemTools.coordinator_execute(cmd)
      t =  DistemTools.vnode_execute('node1', ping_cmd).to_f
      res = 1465/(t-ref)
      error = 100 * ((res - v ).abs / v)
      puts "#For input ref:#{v}kbps, measured:#{res.to_i}kbps (Err: #{error}%)"
      assert error < 20
    end
    [[250, 500], [500, 500], [1000, 500], [2500, 1000]].each do |v|
      cmd = "distem --config-viface vnode=node1,iface=if0,bw=#{v[0]}kbps,direction=INPUT"
      DistemTools.coordinator_execute(cmd)
      cmd = "distem --config-viface vnode=node1,iface=if0,bw=#{v[1]}kbps,direction=OUTPUT"
      DistemTools.coordinator_execute(cmd)
      t =  DistemTools.vnode_execute('node1', ping_cmd).to_f
      res = 2930/(t-ref)
      m = 2930 / ((1465.0/v[0]) + (1465.0/v[1]))
      error = 100 * ((res - m ).abs / m)
      puts "#For input/output ref:i:#{v[0]}, o:#{v[1]}, mean:#{m.to_i}kbps, measured:#{res.to_i}kbps (Err: #{error}%)"
      assert error < 20
    end
  end
end
