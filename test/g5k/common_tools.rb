require 'net/ssh'
require 'net/ssh/multi'
require 'open3'

# Helper for common tasks with tests
class CommonTools
  def self.error(str)
    puts "# ERROR: #{str}"
    exit 1
  end

  def self.msg(str)
    puts "# #{str}"
    STDOUT.flush
  end

  def self.execute_on_frontend(cmd)
    stdout, stderr, status = Open3.capture3(cmd)
    unless status.exitstatus.zero?
      error("Can't execute #{cmd} on frontend: #{stderr}")
    end
    stdout
  end

  def self.execute_ssh(address, cmd, user: 'root')
    Net::SSH.start(address, user) do |session|
      return ssh_exec!(session, cmd)
    end
  end

  def self.copy(pnode, src, dst = '', recursive: false, user: 'root')
    if recursive
      execute_on_frontend('scp -o StrictHostKeyChecking=no -r ' \
                          "#{src} #{user}@#{pnode}:#{dst}")
    else
      execute_on_frontend('scp -o StrictHostKeyChecking=no ' \
                          "#{src} #{user}@#{pnode}:#{dst}")
    end
  end

  def self.ssh_exec!(ssh, command)
    stdout_data = ''
    stderr_data = ''
    exit_code = nil
    ssh.open_channel do |channel|
      channel.exec(command) do |_, success|
        error("Couldn't ssh command #{command}") unless success
        channel.on_data do |_, data|
          stdout_data += data
        end
        channel.on_extended_data do |_, _, data|
          stderr_data += data
        end
        channel.on_request('exit-status') do |_, data|
          exit_code = data.read_long
        end
      end
    end
    ssh.loop
    { stdout: stdout_data, stderr: stderr_data, code: exit_code }
  end

  private_class_method :ssh_exec!
end
