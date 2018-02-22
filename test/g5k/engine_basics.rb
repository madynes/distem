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
# Ignore for now
# IMAGE = ARGV[2] # Image location
IMAGE = "http://public.nancy.grid5000.fr/~amerlin/distem-test-img.tgz"
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

  def test_setup
    CommonTools.msg('Running setup test')
    install_distem
    DistemTools.deploy_topology('1node', @@pnodes, NETWORK)
    conf = eval(DistemTools.coordinator_execute('distem --get-vnode-info')) # Better?
    assert_instance_of Hash, conf
    assert_equal conf.keys.count, 1
    k = conf.keys[0]
    assert_equal conf[k]['name'], 'node1'
    assert_equal conf[k]['status'], 'RUNNING'
  end
end
