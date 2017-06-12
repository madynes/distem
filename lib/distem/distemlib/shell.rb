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
          Open3.popen3(cmd) do |stdin, stdout, stderr, thr|
            ret = stdout.read
            err = stderr.read
            log = "#{cmdlog}\n#{ret}"
            log += "\nError: #{err}" unless err.empty?
            error = !thr.value.success? or !err.empty?
          end
        end
        File.open(PATH_DISTEMD_LOG_CMD,'a+') { |f| f.write(log) }
        raise ShellError.new(cmd,ret,err) if error

        return ret
      end

      def self.run_without_logging(cmd)
        res = {}
        Open3.popen3(cmd) do |stdin, stdout, stderr, thr|
          res[:out] = stdout.read
          res[:err] = stderr.read
          res[:success] = (thr.value.success? and res[:err].empty?) ? 'ok' : 'ko'
        end
        return res
      end
    end

  end
end
