require 'distem'

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

        unless File.exists?(PATH_DEFAULT_CONFIGFILE)
          Lib::Shell.run("mkdir -p #{PATH_DEFAULT_CONFIGFILE}")
        end

        rootfsfile = Lib::FileManager.download(@resource.image)
        uniquefspath = File.join(PATH_DEFAULT_ROOTFS_UNIQUE,@resource.vnode.name)
        sharedfspath = File.join(PATH_DEFAULT_ROOTFS_SHARED,
          Lib::FileManager.file_hash(rootfsfile))

        rootfspath = nil

        if @resource.shared
          rootfspath = Lib::FileManager.extract(rootfsfile,sharedfspath,false)
        else
          rootfspath = Lib::FileManager.extract(rootfsfile,uniquefspath)
        end

        #Check root filesystem
        raise InvalidResourceError 'rootfs_image' unless rootfspath
        procdir = File.join(rootfspath,'proc')
        raise InvalidResourceError 'rootfs_image_path_missing:/proc' \
          unless File.directory?(procdir)
        sysdir = File.join(rootfspath,'sys')
        raise InvalidResourceError 'rootfs_image_path_missing:/sys' \
          unless File.directory?(sysdir)
        devdir = File.join(rootfspath,'dev')
        raise InvalidResourceError 'rootfs_image_path_missing:/dev' \
          unless File.directory?(devdir)

        if @resource.shared
          Lib::Shell.run("rm -Rf #{uniquefspath}") if File.exists?(uniquefspath)
          Lib::Shell.run("mkdir -p #{uniquefspath}")
          Lib::Shell.run("cp -R #{procdir} #{File.join(uniquefspath,'proc')}")
          Lib::Shell.run("cp -R #{sysdir} #{File.join(uniquefspath,'sys')}")
          Lib::Shell.run("cp -R #{devdir} #{File.join(uniquefspath,'dev')}")
          @resource.sharedpath = sharedfspath
          @resource.path = uniquefspath
          
        else
          @resource.path = rootfspath
        end

      end

      def apply() # :nodoc:
      end

    end
  end
end

