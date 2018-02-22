require 'tempfile'
require_relative 'common_tools'

# Helper for distem related task with test
class DistemTools
  IMG_ADDRESS = '/root/image_distem_test.tgz'.freeze
  TEST_ADDRESS = '/root/scripts/'.freeze

  def self.install_distem(pnodes, bootstrap, extra_params = '',
                          git_url: nil, coord: nil)

    # change to tmp file
    f = Tempfile.new('distemnodes', tmpdir = '.')
    pnodes.uniq.each do |pnode|
      f.puts(pnode)
    end
    f.close

    coord ||= pnodes[0]

    @@coord = coord
    @@pnodes = pnodes

    distemcmd = "#{bootstrap} -c #{coord} -f #{f.path} --enable-admin-network"
    distemcmd += " -g -U #{git_url}" if git_url
    distemcmd += " --max-vifaces 250 -r net-ssh-multi #{extra_params}"
    CommonTools.execute_on_frontend(distemcmd)
  end

  def self.quit_distem
    coordinator_execute('distem -q')
    remove_class_variable(:@@coord)
  end

  def self.coordinator_execute(cmd, raw: false)
    ret = CommonTools.execute_ssh(@@coord, cmd)
    return ret if raw
    unless (ret[:code]).zero?
      CommonTools.error("cmd \"#{cmd}\" on coordinator: #{ret[:stderr]}")
    end
    ret[:stdout]
  end

  def self.vnode_execute(vnode, cmd)
    coord_cmd = "distem --execute vnode=#{vnode},command=\"#{cmd}\""
    ret = CommonTools.execute_ssh(@@coord, coord_cmd)
    unless (ret[:code]).zero?
      CommonTools.error("cmd \"#{cmd}\" on coordinator: #{ret[:stderr]}")
    end
    ret[:stdout]
  end

  def self.prepare_coordinator(test_folder, coord)
    CommonTools.copy(coord, test_folder, '.', recursive: true)
  end

  # Could be better
  def self.prepare_pnodes(image_path, pnodes)
    pnodes.each do |pnode|
      CommonTools.copy(pnode, image_path, IMG_ADDRESS)
    end
  end

  def self.get_network_pnodes(pnodes)
    result = {}
    pnodes.each do |pnode|
      ret = CommonTools.execute_ssh(pnode, "ip -o -4 addr s up")
      unless (ret[:code]).zero?
        CommonTools.error("cmd \"#{cmd}\" on #{pnode}: #{ret[:stderr]}")
      end
      # ugly regex to catch ip addr output (ip -json not in stretch :( )
      regex = /^\s*[0-9]+:\s*(?<iface>[[:alnum:]]+)\s*(?<ip>[0-9.]+\/[0-9]+).*$/
      pnode_network = []
      ret.split.each do |line|
        matched = regex.match(line)
        pnode_network << [matched['iface'], matched['ip']]
      end
      ret[pnode] = pnode_network
    end
    return ret
  end

  def self.coordinator
    @@coord
  end

  def self.topologies
    # filter if it end by ".rb" and delete the ".rb"
    coordinator_execute("ls #{TEST_ADDRESS}/topology").split \
    .select { |a| a[-3..-1] == '.rb' }.map { |a| a[0..-4] }
  end

  def self.run_xp(xp, vnodes, extra_param="")
    vnodes_cmd = vnodes.join(',')
    CommonTools.msg("Running #{xp}")
    cmd = "ruby #{TEST_ADDRESS}/experiments/#{xp}.rb " \
          "#{vnodes_cmd} #{extra_param}"
    ret = coordinator_execute(cmd, raw: true)
    if (ret[:code]).zero?
      CommonTools.msg("#{ret[:stdout]}")
      CommonTools.msg("Successfully Run #{xp}")
    else
      CommonTools.error("Can't run #{xp}: \nCMD: #{cmd}" \
                        "\nOUTPUT #{ret[:stdout]} \nERR:#{ret[:stderr]}")
    end

  end

  def self.deploy_topology(deployment, pnodes, network,
                           image: IMG_ADDRESS, verbose: false)
    pnodes_cmd = pnodes.join(',')
    network_cmd = network.join('/')
    CommonTools.msg("Deployment of #{deployment}")
    cmd = "ruby #{TEST_ADDRESS}/topology/#{deployment}.rb " \
          "#{pnodes_cmd} #{network_cmd} #{image}"
    ret = coordinator_execute(cmd, raw: true)
    if (ret[:code]).zero?
      CommonTools.msg("#{ret[:stdout]}") if verbose
      CommonTools.msg("Successfully deployed #{deployment}")
    else
      CommonTools.error("Can't deploy #{deployment}: \nCMD: #{cmd}" \
                        "\nOUTPUT #{ret[:stdout]} \nERR:#{ret[:stderr]}")
    end
  end

end
