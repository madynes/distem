require 'uri'

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

      # Create a new FileSystem
      def initialize(vnode,image,shared = false,cow = false)
        @vnode = vnode
        @image = URI.encode(image)
        @shared = shared
        @cow = cow
        @path = nil
        @sharedpath = nil
      end

      def to_s
        return "vnode: #{@vnode.name}, image: #{@image}, path: #{@path}, sharedpath: #{@sharedpath}, shared #{@shared}, cow #{@cow}"
      end
    end

  end
end
