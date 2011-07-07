require 'wrekavoc'
require 'uri'

module Wrekavoc
  module Resource

    # Wrekavoc Virtual Node filesystem
    class FileSystem
      attr_reader :vnode
      # The URI to the -bootstrapped and compressed- image file
      attr_accessor :image
      # The path to the filesystem on the physical machine
      attr_accessor :path

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
