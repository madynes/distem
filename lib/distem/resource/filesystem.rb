require 'cgi'

module Distem
  module Resource

    # Abstract description of the filesystem used on a VNode
    class FileSystem
      # The VNode associated to this FileSystem
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
      def initialize(image,shared = false,cow = false, disk_throttling = {})
        # checking image
        @image = URI.parse(image) # It should not be CGI.escaped
        @image.scheme = "file" if @image.scheme.nil?

        @shared = shared
        @cow = cow
        @path = nil
        @sharedpath = nil
        @disk_throttling = disk_throttling
      end

    end

  end
end
