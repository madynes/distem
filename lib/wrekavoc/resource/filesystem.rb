require 'wrekavoc'
require 'uri'

module Wrekavoc
  module Resource

    # Abstract description of the filesystem used on a VNode
    class FileSystem
      # The VNode associated to this FileSystem
      attr_reader :vnode
      # The URI to the -bootstrapped and compressed- image file
      attr_accessor :image
      # The path to the filesystem on the physical machine
      attr_accessor :path

      # Create a new FileSystem
      def initialize(vnode,image,path = '')
        @vnode = vnode
        @image = URI.encode(image)
        @path = path
      end

      def to_s
        return "vnode: #{@vnode.name}, image: #{@image}, path: #{@image}"
      end
    end

  end
end
