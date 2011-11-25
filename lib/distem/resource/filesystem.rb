require 'distem'
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
      # The path to the filesystem on the physical machine
      attr_accessor :path
      # The path to shared parts of the filesystem on the physical machine (if there is one)
      attr_accessor :sharedpath

      # Create a new FileSystem
      def initialize(vnode,image,shared = false)
        @vnode = vnode
        @image = URI.encode(image)
        @shared = shared
        @path = nil
        @sharedpath = nil
      end

      def to_s
        return "vnode: #{@vnode.name}, image: #{@image}, path: #{@path}, sharedpath: #{@sharedpath}, shared #{@shared}"
      end
    end

  end
end
