require 'wrekavoc'
require 'uri'

module Wrekavoc
  module Lib

    class FileManager
      PATH_DEFAULT_DOWNLOAD="/tmp/"
      
      # Returns a path to the file on the local machine
      def self.download(uri_str,dir=PATH_DEFAULT_DOWNLOAD)
        uri = URI.parse(uri_str)
        ret = ""
        raise "Protocol not supported" unless uri.scheme == "file"

        ret = uri.path
        raise "File '#{ret}' not found" unless File.exists?(ret)

        return ret
      end
    end

  end
end
