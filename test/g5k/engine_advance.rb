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

class AdvanceTesting < MiniTest::Test
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

  def test_cpu_freq
    CommonTools.msg('# Starting test freq cpu')
    install_distem
    cmd = "distem --create-vnetwork vnetwork=vnet,address=#{NETWORK.join('/')}"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-vnode vnode=N,pnode=#{@@pnodes[0]},rootfs=/root/image_distem_test.tgz"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --set-vcpu vnode=N,corenb=1,cpu_speed=unlimited"
    DistemTools.coordinator_execute(cmd)
    DistemTools.coordinator_execute('distem --start-vnode=N')
    # Ugly...:
    cmd_vnode = "stress-ng --cpu 1 -t 30 -M | grep CPU: | rev | cut -d' ' -f1 | rev"
    ref = DistemTools.vnode_execute('N', cmd_vnode).to_f
    [1.0, 0.8, 0.6, 0.4, 0.2].each do |r|
      cmd = "distem --config-vcpu vnode=N,cpu_speed=#{r},unit=ratio"
      DistemTools.coordinator_execute(cmd)
      res = DistemTools.vnode_execute('N', cmd_vnode).to_f
      error = 100 * (((ref*r) - res ).abs / (ref*r))
      puts "REF: #{(ref*r).round} GET: #{res.round} ERROR #{error}"
      assert error < 20
    end
  end



end
