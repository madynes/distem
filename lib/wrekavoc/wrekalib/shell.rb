module Wrekavoc
  module Lib

    class Shell
      VERBOSE=false

      PATH_WREKAD_LOG_CMD=File.join(FileManager::PATH_WREKAVOC_LOGS,"wrekad.cmd")
      def self.run(cmd)
        puts(cmd) if VERBOSE
        cmdlog = "(#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}) #{cmd}"
        ret = `#{cmd}`
        retlog = ""
        ret.each_line { |line| retlog += "  #{line}" }

        Dir::mkdir(FileManager::PATH_WREKAVOC_LOGS) \
          unless File.exists?(FileManager::PATH_WREKAVOC_LOGS)
        File.open(PATH_WREKAD_LOG_CMD,'a+') { |f| f.write("#{cmdlog}\n#{retlog}") }
      
        raise "['#{cmd}' failed!]" unless $?.success?
        return ret
      end
    end

  end
end
