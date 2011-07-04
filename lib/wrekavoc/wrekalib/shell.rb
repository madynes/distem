require 'open3'

module Wrekavoc
  module Lib

    class Shell

      PATH_WREKAD_LOG_CMD=File.join(FileManager::PATH_WREKAVOC_LOGS,"wrekad.cmd")
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
            Dir::mkdir(FileManager::PATH_WREKAVOC_LOGS) \
              unless File.exists?(FileManager::PATH_WREKAVOC_LOGS)
            log = "#{cmdlog}\n#{ret}"
            log += "\nError: #{err}" unless err.empty? 
            error = !$?.success? or !err.empty?
          end
        end
        File.open(PATH_WREKAD_LOG_CMD,'a+') { |f| f.write(log) }
        raise ShellError.new(cmd,ret,err) if error

        return ret
      end
    end

  end
end
