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
    sleep 10
    cmd ='dd if=/dev/urandom of=file bs=1M count=100'
    DistemTools.vnode_execute('node1', cmd)
    src_hash = DistemTools.vnode_execute('node1', 'md5sum file')
    cmd = 'scp -o StrictHostKeyChecking=no file root@node2-vnet:'
    DistemTools.vnode_execute('node1', cmd)
    dst_hash = DistemTools.vnode_execute('node2', 'md5sum file')
    assert_equal src_hash, dst_hash
  end

  def _test_bandwidth_input
    CommonTools.msg('Running bandwidth input test')
    install_distem
    DistemTools.deploy_topology('2nodes', @@pnodes, NETWORK)
    @@launched = false
  end


end
