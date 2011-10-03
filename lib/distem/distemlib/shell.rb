require 'distem'
require 'open3'

module Distem
  module Lib

    class Shell

      # The file to save log of the executed commands
      PATH_DISTEMD_LOG_CMD=File.join(Distem::Node::Admin::PATH_DISTEM_LOGS,"distemd.cmd")
      # Execute the specified command on the physical node (log the resuls in PATH_DISTEMD_LOG_CMD)
      # ==== Attributes
      # * +cmd+ The command (String)
      # * +simple+ Execute the command in simple mode (no logs of stderr)
      def self.run(cmd, simple=false)
        cmdlog = "(#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}) #{cmd}"

        ret = ""
        log = ""
        error = false
        err = ""

        if simple
          ret = `#{cmd}`
          log = "#{cmdlog}\n#{ret}"
          error = !$?.success?
        else
          Open3.popen3(cmd) do |stdin, stdout, stderr|
            ret = stdout.read
            err = stderr.read
            Dir::mkdir(Distem::Node::Admin::PATH_DISTEM_LOGS) \
              unless File.exists?(Distem::Node::Admin::PATH_DISTEM_LOGS)
            log = "#{cmdlog}\n#{ret}"
            log += "\nError: #{err}" unless err.empty? 
            error = !$?.success? or !err.empty?
          end
        end
        File.open(PATH_DISTEMD_LOG_CMD,'a+') { |f| f.write(log) }
        raise ShellError.new(cmd,ret,err) if error

        return ret
      end
    end

  end
end
