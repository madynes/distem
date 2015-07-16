require 'open3'

module Distem
  module Lib

    class Shell
      @@count = 0
      # The file to save log of the executed commands
      PATH_DISTEMD_LOG_CMD=File.join(Distem::Node::Admin::PATH_DISTEM_LOGS,"distemd.cmd")
      # Execute the specified command on the physical node (log the resuls in PATH_DISTEMD_LOG_CMD)
      # ==== Attributes
      # * +cmd+ The command (String)
      # * +simple+ Execute the command in simple mode (no logs of stderr)
      def self.run(cmd, simple=false)
        @@count = @@count + 1
        cmdlog = "(#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}-#{@@count}) #{cmd}"

        ret = ""
        log = ""
        error = false
        err = ""

        if simple
          ret = `#{cmd}`
          log = "#{cmdlog}\n#{ret}"
          error = !$?.success?
        else
          Dir::mkdir(Distem::Node::Admin::PATH_DISTEM_LOGS) unless File.exist?(Distem::Node::Admin::PATH_DISTEM_LOGS)
          full_version = RUBY_VERSION.split('.')
          main_version = full_version[0] + '.' + full_version[1]
          case main_version
          when '1.8'
            Open3.popen3(cmd) do |stdin, stdout, stderr|
              ret = stdout.read
              err = stderr.read
              log = "#{cmdlog}\n#{ret}"
              log += "\nError: #{err}" unless err.empty? 
              error = !$?.success? or !err.empty?
            end
          when '1.9','2.0','2.1'
            Open3.popen3(cmd) do |stdin, stdout, stderr, thr|
              ret = stdout.read
              err = stderr.read
              log = "#{cmdlog}\n#{ret}"
              log += "\nError: #{err}" unless err.empty? 
              error = !thr.value.success? or !err.empty?
            end
          else
            raise "Unsupported Ruby version: #{RUBY_VERSION}"
          end
        end
        File.open(PATH_DISTEMD_LOG_CMD,'a+') { |f| f.write(log) }
        raise ShellError.new(cmd,ret,err) if error

        return ret
      end
    end

  end
end
