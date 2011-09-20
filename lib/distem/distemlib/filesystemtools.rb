require 'distem'

module Distem
  module Lib

    # Class that allow to perform physical operations on a physical filesystem resource
    class FileSystemTools
      def self.set_limits()
        Shell.run("sysctl fs.inotify.max_user_instances=1024")
      end
    end

  end
end
