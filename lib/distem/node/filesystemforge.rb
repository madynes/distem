require 'distem'

module Distem
  module Node

    # Allows to modify filesystem physical resources to fit with the virtual resources specifications
    class FileSystemForge < Forge
      # The directory to save container configuration files
      PATH_DEFAULT_CONFIGFILE="/tmp/distem/config/"
      # The directory used to save virtual nodes filesystem directories&files
      PATH_DEFAULT_ROOTFS="/tmp/distem/rootfs/"


      # Create a new FileSystemForge specifying the virtual node resource to modify 
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def initialize(vnode)
        super(vnode,nil)

        unless File.exists?(PATH_DEFAULT_CONFIGFILE)
          Lib::Shell.run("mkdir -p #{PATH_DEFAULT_CONFIGFILE}")
        end

        rootfsfile = Lib::FileManager.download(vnode.filesystem.image)
        rootfspath = File.join(PATH_DEFAULT_ROOTFS,vnode.name)

        rootfspath = Lib::FileManager.extract(rootfsfile,rootfspath)
        vnode.filesystem.path = rootfspath
      end

      def apply() # :nodoc:
      end

    end
  end
end

