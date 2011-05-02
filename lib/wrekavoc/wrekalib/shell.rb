module Wrekavoc
  module Lib

    VERBOSE=false

    class Shell
      def self.run(cmd)
        puts(cmd) if VERBOSE
        ret = `#{cmd}`
        raise "['#{cmd}' failed!]" unless $?.success?
        return ret
      end
    end

  end
end
