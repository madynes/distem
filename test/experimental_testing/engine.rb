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

REFFILE = ARGV[0]
GITREPO = ARGV[1]

KADEPLOY_ENVIRONMENT = 'squeeze-x64-nfs'
IMAGE = 'file:///home/ejeanvoine/distem-fs-v3.tar.gz'
ROOT = '/home/ejeanvoine/distem/test/experimental_testing'
USER = `id -nu`.strip
NET = '10.144.0.0/18'
MIN_PNODES = 2

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
      system("kareboot3 -V 0 -r simple_reboot #{node_list} -o #{ok.path} --vlan #{vlan}")
      next if not File.exists?(ok.path)
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
      system("kadeploy3 -V 0 #{node_list} -e #{environment} -k -o #{ok.path} --vlan #{vlan}")
      next if not File.exists?(ok.path)
      deployed_pnodes = IO.readlines(ok.path).collect { |line| line.strip }
      break if (deployed_pnodes.length == pnodes.length)
    }
    return deployed_pnodes
  end

  def CommonTools::clean_nodes(pnodes)
    msg("Cleaning #{pnodes.join(',')}")
    Net::SSH::Multi.start { |session|
      pnodes.each { |pnode| 
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
    @@coordinator = nodes.first
    @@pnodes = nodes
    @@initialized = true
  end
  
  def clean_env
    CommonTools::reboot_nodes(@@deployed_nodes, @@vlan)
    CommonTools::clean_nodes(@@pnodes)
  end

  def check_result(str)
    assert(str.include?("TEST PASSED"), str)
  end

  def install_distem
    f = Tempfile.new("distemnodes")
    @@pnodes.each { |pnode|
      f.puts(pnode)
    }
    f.close
    if GITREPO
      system("/grid5000/code/bin/distem-bootstrap -c #{@@coordinator} -f #{f.path} -U #{GITREPO}")
    else
      system("/grid5000/code/bin/distem-bootstrap -c #{@@coordinator} -f #{f.path}")
    end
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

  ##############################
  #####   Tests start here #####
  ##############################

  def test_A0_setup_ok
    assert_not_nil(@@coordinator)
    assert_not_nil(@@pnodes)
  end

  def test_A1_platform_api
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '2nodes', 'pnodes' => @@pnodes})
    }
  end

  def test_A2_platform_cli
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '2nodes', 'pnodes' => @@pnodes, 'cli' => true})
    }
  end

  def test_A3_latency
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '2nodes', 'pnodes' => @@pnodes})
      check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-latency.rb')} #{@@ref['latency']['error']}"))
    }
  end

  def test_A4_bandwidth
    Net::SSH.start(@@coordinator, USER) { |session|
      launch_vnodes(session, {'pf_kind' => '2nodes', 'pnodes' => @@pnodes})
      check_result(session.exec!("ruby #{File.join(ROOT,'exps/exp-bandwidth.rb')} #{@@ref['bandwidth']['error']}"))
    }
  end

  def test_A5_hpcc_gov
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

  def test_A6_hpcc_hogs
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
end
