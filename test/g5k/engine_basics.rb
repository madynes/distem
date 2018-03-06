require_relative 'common_tools'
require_relative 'distem_tools'
require 'minitest/autorun'

MIN_PNODES = 1

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

class BasicTesting < MiniTest::Test
  @@pnodes = PNODES
  @@initialized = false
  @@launched = false
  @@coordinator = nil


  def install_distem
    @@coordinator = @@pnodes[0]
    CommonTools.msg('Installing Distem')
    DistemTools.install_distem(@@pnodes, BOOTSTRAP, git_url: GIT,
                               coord: @@coordinator)
    @@launched = true
  end

  def setup
    @@coordinator = @@pnodes[0]
    CommonTools.msg('Setting up Distem')
    DistemTools.prepare_coordinator(TEST_LOCATION, @@coordinator)
    DistemTools.prepare_pnodes(IMAGE, @@pnodes)
  end

  def teardown
    CommonTools.msg('Quiting Distem')
    DistemTools.quit_distem if @@launched
    @@launched = false
    @@coordinator = nil
  end

  def test_deploy
    CommonTools.msg('Running deploy test')
    install_distem
    DistemTools.deploy_topology('1node', @@pnodes, NETWORK)
    conf = eval(DistemTools.coordinator_execute('distem --get-vnode-info'))
    assert_instance_of Hash, conf
    assert_equal conf.keys.count, 1
    k = conf.keys[0]
    assert_equal conf[k]['name'], 'node1'
    assert_equal conf[k]['status'], 'RUNNING'
  end

  def test_lxc
    CommonTools.msg('Running lxc test')
    install_distem
    pnode = @@pnodes[0]
    cmd = "distem --create-vnode vnode=testnode,pnode=#{pnode},rootfs=/root/image_distem_test.tgz"
    DistemTools.coordinator_execute(cmd)
    DistemTools.coordinator_execute("distem --start-vnode testnode")
    assert_equal DistemTools.lxc_state('testnode', pnode), 'RUNNING'
    DistemTools.coordinator_execute("distem --stop-vnode testnode")
    assert_equal DistemTools.lxc_state('testnode', pnode), 'STOPPED'
    DistemTools.coordinator_execute("distem --start-vnode testnode")
    assert_equal DistemTools.lxc_state('testnode', pnode), 'RUNNING'
    DistemTools.coordinator_execute("distem --stop-vnode testnode")
    assert_equal DistemTools.lxc_state('testnode', pnode), 'STOPPED'
    DistemTools.coordinator_execute("distem --remove-vnode testnode")
    assert_equal DistemTools.lxc_state('testnode', pnode), 'NOTHERE'
  end

  def test_iface
    CommonTools.msg('Running iface test')
    install_distem
    pnode = @@pnodes[0]
    assert NETWORK[1].to_i <= 22
    subnet1 = NETWORK[0]
    m = subnet1.match(/(\d+)\.(\d+)\.(\d+)\.(\d+)/)
    new_m3 = m[3].to_i + 1
    subnet2 = "#{m[1]}.#{m[2]}.#{new_m3}.#{m[4]}"
    cmd = "distem --create-vnetwork vnetwork=vnetwork1,address=#{subnet1}/24"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-vnetwork vnetwork=vnetwork2,address=#{subnet2}/24"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-vnode vnode=testnode,pnode=#{pnode},rootfs=/root/image_distem_test.tgz"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-viface vnode=testnode,iface=if0,vnetwork=vnetwork1"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-viface vnode=testnode,iface=if1,vnetwork=vnetwork2"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --remove-viface vnode=testnode,iface=if1"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-viface vnode=testnode,iface=if2,vnetwork=vnetwork2"
    DistemTools.coordinator_execute(cmd)
    DistemTools.coordinator_execute("distem --start-vnode testnode")
    assert DistemTools.iface_exist("if0", "testnode", pnode)
    refute DistemTools.iface_exist("if1", "testnode", pnode)
    assert DistemTools.iface_exist("if2", "testnode", pnode)
  end

  def test_algo
    CommonTools.msg('Running algo switch test')
    install_distem
    pnode = @@pnodes[0]
    conf = eval(DistemTools.coordinator_execute("distem --get-pnode-info #{pnode}"))
    assert_instance_of Hash, conf
    assert_equal conf['algorithms']['cpu'].upcase, 'HOGS'
    DistemTools.run_xp('switch_algo', ['no_vnode'], "#{pnode} gov")
    conf = eval(DistemTools.coordinator_execute("distem --get-pnode-info #{pnode}"))
    assert_instance_of Hash, conf
    assert_equal conf['algorithms']['cpu'].upcase, 'GOV'
  end

  def test_tc
    CommonTools.msg('Running tc test')
    install_distem
    pnode = @@pnodes[0]
    cmd = "distem --create-vnetwork vnetwork=vnetwork,address=#{NETWORK[0]}/#{NETWORK[1]}"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-vnode vnode=testnode,pnode=#{pnode},rootfs=/root/image_distem_test.tgz"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-viface vnode=testnode,iface=if0,vnetwork=vnetwork"
    DistemTools.coordinator_execute(cmd)
    DistemTools.coordinator_execute("distem --start-vnode testnode")
    cmd = "distem --config-viface vnode=testnode,iface=if0,loss=25%,direction=INPUT"
    DistemTools.coordinator_execute(cmd)
    out_tc = DistemTools.tc_state(pnode, 'testnode', 'if0')
    assert out_tc.match(/loss 25%/)
    cmd = "distem --config-viface vnode=testnode,iface=if0,duplication=10%,corruption=50%,direction=INPUT"
    DistemTools.coordinator_execute(cmd)
    out_tc = DistemTools.tc_state(pnode, 'testnode', 'if0')
    refute out_tc.match(/loss/)
    assert out_tc.match(/duplicate 10%/)
    assert out_tc.match(/corrupt 50%/)
    cmd = "distem --config-viface vnode=testnode,iface=if0,latency=1s,direction=INPUT"
    DistemTools.coordinator_execute(cmd)
    out_tc = DistemTools.tc_state(pnode, 'testnode', 'if0')
    refute out_tc.match(/loss/)
    refute out_tc.match(/duplicate/)
    refute out_tc.match(/corrupt/)
    assert out_tc.match(/delay (1\.0s|1s|1000ms)/)
  end

end
