#require 'distem'

module Distem
  module Node

    # Allows to modify filesystem physical resources to fit with the virtual resources specifications
    class FileSystemForge < Forge
      # The directory to save container configuration files
      PATH_DEFAULT_CONFIGFILE="/tmp/distem/config/"
      # The directory used to save virtual nodes unique filesystem directories&files
      PATH_DEFAULT_ROOTFS_UNIQUE="/tmp/distem/rootfs-unique/"
      # The directory used to save virtual nodes unique filesystem directories&files
      PATH_DEFAULT_ROOTFS_SHARED="/tmp/distem/rootfs-shared/"


      # Create a new FileSystemForge specifying the virtual node resource to modify
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def initialize(vnode)
        super(vnode.filesystem,nil)

        unless File.exist?(PATH_DEFAULT_CONFIGFILE)
          Lib::Shell.run("mkdir -p #{PATH_DEFAULT_CONFIGFILE}")
        end

        rootfsfile = Lib::FileManager.download(@resource.image)
        uniquefspath = File.join(PATH_DEFAULT_ROOTFS_UNIQUE,@resource.vnode.name)

        block = Proc.new { |filepath,mode|
          Lib::Shell.run("rm -Rf #{filepath}") if File.exist?(filepath)
          Lib::Shell.run("mkdir #{(mode ? "-m #{mode}" : '')} -p #{filepath}")
        }

        block.call(File.join(uniquefspath,'proc'),755)
        block.call(File.join(uniquefspath,'sys'),755)
        block.call(File.join(uniquefspath,'dev','pts'),744)
        # Not necessary at the moment
        #block.call(File.join(uniquefspath,'dev','shm'),1777)
        #block.call(File.join(uniquefspath,'home','my'),755)

        if @resource.shared
          sharedfspath = File.join(PATH_DEFAULT_ROOTFS_SHARED,
            Lib::FileManager.file_hash(rootfsfile))
          sharedfspath = Lib::FileManager.extract(rootfsfile,sharedfspath,false,false)
          raise InvalidResourceError 'rootfs_image' unless sharedfspath

          @resource.sharedpath = sharedfspath
          @resource.path = uniquefspath
        else
          uniquefspath = Lib::FileManager.extract(rootfsfile,uniquefspath,true,vnode.filesystem.cow)
          raise InvalidResourceError 'rootfs_image' unless uniquefspath
          @resource.path = uniquefspath
        end
      end

      def apply() # :nodoc:
      end

    end
  end
end

