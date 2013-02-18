
module Distem
  module Lib

    # Class that allow to perform physical operations on a physical filesystem resource
    class FileSystemTools
      # Set up a physical machine filesystem properties
      # ==== Attributes
      #
      def self.set_resource()
        Shell.run("sysctl -w fs.inotify.max_user_instances=1024")
      end
    end

  end
end
