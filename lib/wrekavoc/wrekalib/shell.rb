module Wrekavoc
  module Lib

    class Shell

      PATH_WREKAD_LOG_CMD=File.join(FileManager::PATH_WREKAVOC_LOGS,"wrekad.cmd")
      def self.run(cmd)
        cmdlog = "(#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}) #{cmd}"
        ret = `#{cmd}`
        raise ShellError.new(cmd,ret) unless $?.success?

        retlog = ""
        ret.each_line { |line| retlog += "  #{line}" }
        Dir::mkdir(FileManager::PATH_WREKAVOC_LOGS) \
          unless File.exists?(FileManager::PATH_WREKAVOC_LOGS)
        File.open(PATH_WREKAD_LOG_CMD,'a+') { |f| f.write("#{cmdlog}\n#{retlog}") }
      
        return ret
      end
    end

  end
end
