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

  def create_simple_vnode(n)
    cmd = "distem --create-vnetwork vnetwork=vnetwork,address=#{NETWORK[0]}/#{NETWORK[1]}"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-vnode vnode=#{n},pnode=#{@@pnodes[0]},rootfs=/root/image_distem_test.tgz"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-viface vnode=#{n},iface=if0,vnetwork=vnetwork"
    DistemTools.coordinator_execute(cmd)
  end


  def test_cpu_gov_freq
    CommonTools.msg('# Starting test freq gov cpu')
    install_distem
    create_simple_vnode('N')
    DistemTools.run_xp('switch_algo', ['no_vnode'], "#{@@pnodes[0]} gov")
    cmd = "distem --set-vcpu vnode=N,corenb=1,cpu_speed=unlimited"
    DistemTools.coordinator_execute(cmd)
    DistemTools.coordinator_execute('distem --start-vnode=N')
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

  def test_cpu_hogs_freq
    CommonTools.msg('# Starting test freq hogs cpu')
    install_distem
    create_simple_vnode('N')
    cmd = "distem --set-vcpu vnode=N,corenb=1,cpu_speed=unlimited"
    DistemTools.coordinator_execute(cmd)
    DistemTools.coordinator_execute('distem --start-vnode=N')
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

  def test_nb_core
    CommonTools.msg('# Starting test number of core')
    install_distem
    create_simple_vnode('N')
    cmd = "distem --set-vcpu vnode=N,corenb=1,cpu_speed=unlimited"
    DistemTools.coordinator_execute(cmd)
    DistemTools.coordinator_execute('distem --start-vnode=N')
    cmd_vnode = "stress-ng --cpu 10 -t 30 -M | grep CPU: | cut -d' ' -f 5"
    ref = DistemTools.vnode_execute('N', cmd_vnode).to_i
    puts "1 core: #{ref}"

    DistemTools.coordinator_execute('distem --stop-vnode=N')
    DistemTools.coordinator_execute('distem --remove-vnode=N')
    cmd = "distem --create-vnode vnode=N2,pnode=#{@@pnodes[0]},rootfs=/root/image_distem_test.tgz"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --set-vcpu vnode=N2,corenb=2,cpu_speed=unlimited"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-viface vnode=N2,iface=if0,vnetwork=vnetwork"
    DistemTools.coordinator_execute(cmd)
    DistemTools.coordinator_execute('distem --start-vnode=N2')
    val = DistemTools.vnode_execute('N2', cmd_vnode).to_i
    error = 100 * (val - 2 * ref).abs.to_f / (2 * ref)
    puts "2 cores: #{val} (err #{error.to_i}%)"
    assert error < 25

    DistemTools.coordinator_execute('distem --stop-vnode=N2')
    DistemTools.coordinator_execute('distem --remove-vnode=N2')
    cmd = "distem --create-vnode vnode=N3,pnode=#{@@pnodes[0]},rootfs=/root/image_distem_test.tgz"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --set-vcpu vnode=N3,corenb=3,cpu_speed=unlimited"
    DistemTools.coordinator_execute(cmd)
    cmd = "distem --create-viface vnode=N3,iface=if0,vnetwork=vnetwork"
    DistemTools.coordinator_execute(cmd)
    DistemTools.coordinator_execute('distem --start-vnode=N3')
    val = DistemTools.vnode_execute('N3', cmd_vnode).to_i
    error = 100 * (val - 3 * ref).abs.to_f / (3 * ref)
    puts "3 cores: #{val} (err #{error.to_i}%)"
    assert error < 25
  end

end
