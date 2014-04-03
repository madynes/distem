require 'cgi'

module Distem
  module Resource

    # Abstract description of the filesystem used on a VNode
    class FileSystem
      # The VNode associated to this FileSystem
      attr_accessor :vnode
      # The URI to the -bootstrapped and compressed- image file
      attr_accessor :image
      # Is the file system shared between several nodes ?
      attr_reader :shared
      # Is the filesystem use an underline COW filesystem ?
      attr_reader :cow
      # The path to the filesystem on the physical machine
      attr_accessor :path
      # The path to shared parts of the filesystem on the physical machine (if there is one)
      attr_accessor :sharedpath
      # Disk throttling properties
      attr_accessor :disk_throttling


      # Create a new FileSystem
      def initialize(vnode,image,shared = false,cow = false, disk_throttling = {})
        @vnode = vnode
        @image = CGI.escape(image)
        @shared = shared
        @cow = cow
        @path = nil
        @sharedpath = nil
        @disk_throttling = disk_throttling
      end

      def to_s
        return "vnode: #{@vnode.name}, image: #{CGI.unescape(@image)}, path: #{@path}, sharedpath: #{@sharedpath}, shared #{@shared}, cow #{@cow}, disk_throttling: #{@disk_throttling ? @disk_throttling.to_s : nil}"
      end
    end

  end
end
