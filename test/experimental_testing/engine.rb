
#!/usr/bin/ruby
# Experimental test suite for Distem
# - supposed to be executed inside an OAR reservation with KaVLAN
# - netssh and netssh/multi gems must be installed

require 'test/unit'
require 'tempfile'
require 'yaml'
require 'pp'
require 'rubygems'
require 'net/ssh'
require 'net/ssh/multi'

MODE = ARGV[0] #ci or g5k
DISTEMROOT = ARGV[1]

DISTEMBOOTSTRAP = "#{DISTEMROOT}/scripts/distem-bootstrap"
ROOT = "#{DISTEMROOT}/test/experimental_testing"
USER = `id -nu`.strip
NET = '10.144.0.0/18'

if MODE == 'g5k'
  GIT = (ARGV[2] == 'true')
  CLUSTER = ARGV[3]
  GITREPO = ARGV[4]
  KADEPLOY_ENVIRONMENT = 'wheezy-x64-nfs'
  IMAGE = 'file:///home/ejeanvoine/distem-fs-wheezy.tar.gz'
  REFFILE = "#{ROOT}/ref_#{CLUSTER}.yml"
  MIN_PNODES = 2
else
  IMAGE = 'file:///builds/distem-fs-wheezy.tar.gz'
  REFFILE = "#{ROOT}/ref_ci.yml"
end


module Kernel
private
  def this_method
    caller[0] =~ /`([^']*)'/ and $1
  end
end

class CommonTools
  def CommonTools::error(str)
    puts "# ERROR: #{str}"
    exit 1
  end

  def CommonTools::msg(str)
    puts "# #{str}"
    STDOUT.flush
  end

  def CommonTools::reboot_nodes(pnodes, vlan)
    system("kavlan -s -i DEFAULT")
    nb_rebooted_nodes = nil
    10.times.each { |i|
      msg("Rebooting #{pnodes.join(',')} (attempt #{i+1})")
      ok = Tempfile.new("nodes_ok")
      node_list = "-m #{pnodes.join(' -m ')}"
      system("kareboot3 -V 1 -r simple #{node_list} -o #{ok.path} --vlan #{vlan}")
      next if not File.exist?(ok.path)
      nb_rebooted_nodes = IO.readlines(ok.path).length
      break if (nb_rebooted_nodes == pnodes.length)
    }
    return (nb_rebooted_nodes == pnodes.length)
  end

  def CommonTools::deploy_nodes(pnodes, vlan, environment)
    deployed_pnodes = nil
    10.times.each { |i|
      msg("Deploying #{pnodes.join(',')} (attempt #{i+1})")
      ok = Tempfile.new("nodes_ok")
      node_list = "-m #{pnodes.join(' -m ')}"
      system("kadeploy3 -V 1 #{node_list} -e #{environment} -k -o #{ok.path} --vlan #{vlan}")
      next if not File.exist?(ok.path)
      deployed_pnodes = IO.readlines(ok.path).collect { |line| line.strip }
      break if (deployed_pnodes.length == pnodes.length)
    }
    return deployed_pnodes
  end

  def CommonTools::clean_nodes(pnodes)
    msg("Cleaning #{pnodes.join(',')}")
    Net::SSH::Multi.start { |session|
      pnodes.uniq.each { |pnode|
        session.use("root@#{pnode}")
      }
      session.exec('rm -rf /tmp/distem')
      session.loop
    }
  end
end

class ExperimentalTesting < Test::Unit::TestCase
  @@initialized = false
  @@coordinator = nil
  @@pnodes = nil
  @@deployed_nodes = nil
  @@vlan = nil
  @@ref = nil

  def plateform_init
    @@ref = YAML::load_file(REFFILE)
    if MODE == 'g5k'
      CommonTools::error("This script must be run inside an OAR reservation") if not ENV['OAR_JOB_ID']
      @@vlan = `kavlan -V -j #{ENV['OAR_JOB_ID']}`.strip
      CommonTools::error("No VLAN found") if @@vlan == 'no vlan found'
      oar_nodes = IO.readlines(ENV['OAR_NODE_FILE']).collect { |line| line.strip }.uniq
      CommonTools::error("Not enough nodes") if oar_nodes.length < MIN_PNODES
      system("kavlan -e")
      @@deployed_nodes = CommonTools::deploy_nodes(oar_nodes, @@vlan, KADEPLOY_ENVIRONMENT)
      CommonTools::error("Not enough nodes after deployment") if @@deployed_nodes.length < oar_nodes.length
      nodes = @@deployed_nodes.collect { |node|
        t = node.split('.')
        t.shift + "-kavlan-#{@@vlan}." + t.join('.')
      }
    else
      nodes = [ 'distem-n1','distem-n1' ]
    end
    @@coordinator = nodes.first
    @@pnodes = nodes
    @@initialized = true
  end

  def clean_env
    CommonTools::reboot_nodes(@@deployed_nodes, @@vlan) if MODE == 'g5k'
    CommonTools::clean_nodes(@@pnodes)
  end

  def check_result(str)
    assert(str.include?("TEST PASSED"), str)
  end

  def install_distem
    f = Tempfile.new("distemnodes")
    @@pnodes.uniq.each { |pnode|
      f.puts(pnode)
    }
    f.close
    distemcmd = ''
    if (MODE == 'g5k')
      distemcmd += "#{DISTEMBOOTSTRAP} -c #{@@coordinator} -f #{f.path}"
      distemcmd += " -U #{GITREPO}" if GITREPO
      distemcmd += ' -g' if GIT
    else
      distemcmd += "#{DISTEMBOOTSTRAP} -c #{@@coordinator} -f #{f.path} -g --ci #{DISTEMROOT}"
    end
    distemcmd += ' --max-vifaces 250'
    system(distemcmd)
  end

  def launch_vnodes(ssh, opts)
    pf_kind = opts['pf_kind']
    return false if not pf_kind
    pnodes = opts['pnodes'] if opts['pnodes']
    cli = opts['cli'] ? opts['cli'] : false

    case pf_kind
    when '1node_cpu'
      if cli
        return false
      else
        return ssh_exec(ssh, "ruby #{File.join(ROOT,'platforms/distem_platform_1node-api.rb')} #{NET} /tmp/ip #{IMAGE}")
      end
    when '2nodes'
      if cli
        return ssh_exec(ssh, "ruby #{File.join(ROOT,'platforms/distem_platform_2nodes-cli.rb')} #{NET} #{pnodes[0]},#{pnodes[1]} /tmp/ip #{IMAGE}")
      else
        return ssh_exec(ssh, "ruby #{File.join(ROOT,'platforms/distem_platform_2nodes-api.rb')} #{NET} #{pnodes[0]},#{pnodes[1]} /tmp/ip #{IMAGE}")
      end
    when '50nodes'
      if cli
        return false
      else
        return ssh_exec(ssh, "ruby #{File.join(ROOT,'platforms/distem_platform_50nodes-api.rb')} #{NET} /tmp/ip #{IMAGE}")
      end
    when '200nodes'
      if cli
        return false
      else
        return ssh_exec(ssh, "ruby #{File.join(ROOT,'platforms/distem_platform_200nodes-api.rb')} #{NET} /tmp/ip #{IMAGE}")
      end
    else
      raise "Invalid platform kind"
    end
  end

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
    assert(exit_code == 0, "#STDOUT: #{stdout_data}\n#STDERR: #{stderr_data}\n#EXIT STATUS: #{exit_code}\n#EXIT SIGNAL #{exit_signal}\n")
    [stdout_data, stderr_data, exit_code, exit_signal]
  end

  def setup
    plateform_init if not @@initialized
    clean_env
    install_distem
  end

  def teardown
    Net::SSH.start(@@coordinator, USER) { |session|
      session.exec!('distem -q')
    }
  end
  ##############################
  #####   Tests start here #####
  ##############################

  def test_00_setup_ok
    puts "\n\n**** Running #{this_method} ****"
    assert_not_nil(@@coordinator)
    assert_not_nil(@@pnodes)
  end

  def test_01_platform_api
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '2nodes', 'pnodes' => @@pnodes})
    }
  end

  def test_02_platform_cli
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '2nodes', 'pnodes' => @@pnodes, 'cli' => true})
    }
  end

  def test_03_latency_input
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '2nodes', 'pnodes' => @@pnodes})
      check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-latency.rb')} #{@@ref['latency']['error']} input #{MODE == 'g5k' ? 3:1}"))
    }
  end

  def test_04_latency_output
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '2nodes', 'pnodes' => @@pnodes})
      check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-latency.rb')} #{@@ref['latency']['error']} output #{MODE == 'g5k' ? 3:1}"))
    }
  end

  def test_05_bandwidth_input
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '2nodes', 'pnodes' => @@pnodes})
      check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-bandwidth.rb')} #{@@ref['bandwidth']['error']} input #{MODE == 'g5k' ? 3:1}"))
    }
  end

  def test_06_bandwidth_output
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '2nodes', 'pnodes' => @@pnodes})
      check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-bandwidth.rb')} #{@@ref['bandwidth']['error']} output #{MODE == 'g5k' ? 3:1}"))
    }
  end

  def test_07_hpcc_gov
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
     launch_vnodes(session, {'pf_kind' => '1node_cpu'})
      [1,4].each { |nb_cpu|
        cpu = "#{nb_cpu}cpu"
        (0..(@@ref['hpcc']['freqs'].length - 1)).each { |i|
          check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-hpcc.rb')} #{nb_cpu} gov #{@@ref['hpcc']['freqs'][i]} #{@@ref['hpcc']['error']} #{@@ref['hpcc']['results'][cpu]['dgemm'][i]} #{@@ref['hpcc']['results'][cpu]['fft'][i]} #{@@ref['hpcc']['results'][cpu]['hpl'][i]}"))
        }
      }
    }
  end

  def test_08_hpcc_hogs
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '1node_cpu'})
      [1,4].each { |nb_cpu|
        cpu = "#{nb_cpu}cpu"
        (0..(@@ref['hpcc']['freqs'].length - 1)).each { |i|
          check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-hpcc.rb')} #{nb_cpu} HOGS #{@@ref['hpcc']['freqs'][i]} #{@@ref['hpcc']['error']} #{@@ref['hpcc']['results'][cpu]['dgemm'][i]} #{@@ref['hpcc']['results'][cpu]['fft'][i]} #{@@ref['hpcc']['results'][cpu]['hpl'][i]}"))
        }
      }
    }
 end

  def test_09_vectorized_init_and_connectivity
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '50nodes'})
      @@pnodes.uniq.each { |pnode|
        session.exec!("scp /tmp/ip #{pnode}:/tmp") if (pnode != @@coordinator)
      }
    }
    @@pnodes.uniq.each { |pnode|
      Net::SSH.start(pnode, USER) { |session|
        check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-check-connectivity.rb')}"))
      }
    }
 end

  def test_10_set_peers_latency
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '50nodes'})
      check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-matrix-latencies.rb')}"))
    }
  end

  def test_11_set_arptables
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '50nodes'})
      check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-check-arp-tables.rb')}"))
    }
  end

  def test_12_wait_vnodes
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '200nodes', 'pnodes' => @@pnodes})
    }
  end

  def test_13_cpu_update
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '1node_cpu'})
      max_freq = @@ref['hpcc']['freqs'].last
      [1,2,4].each { |nb_cpu|
        ['HOGS','GOV'].each { |policy|
          check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-cpu.rb')} #{nb_cpu} #{policy} #{max_freq}"))
        }
      }
    }
  end

  def test_14_events
    puts "\n\n**** Running #{this_method} ****"
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '2nodes', 'pnodes' => @@pnodes})
      check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-events.rb')}"))
    }
  end

end
