require 'wrekavoc'
require 'uri'

module Wrekavoc
  module Lib

    class FileManager
      PATH_DEFAULT_DOWNLOAD="/tmp/"

      BIN_TAR="/usr/bin/tar"
      BIN_GUNZIP="/bin/gunzip"
      BIN_BUNZIP2="/bin/bunzip2"
      BIN_UNZIP="/usr/bin/unzip"
      
      # Returns a path to the file on the local machine
      def self.download(uri_str,dir=PATH_DEFAULT_DOWNLOAD)
        uri = URI.parse(uri_str)
        ret = ""
        
        case uri.scheme
          when "file"
            ret = uri.path
            raise "File '#{ret}' not found" unless File.exists?(ret)
          else
            raise "Protocol not supported" unless uri.scheme == "file"
        end

        return ret
      end

      def self.extract(archivefile,targetdir="")
        raise "File '#{archivefile}' not found" unless File.exists?(archivefile)

        basename = File.basename(archivefile)
        extname = File.extname(archivefile)
        link=false

        if targetdir.empty?
          targetdir = File.dirname(archivefile)
        else
          unless File.exists?(targetdir)
            Lib::Shell.run("mkdir -p #{targetdir}")
          end
          Lib::Shell.run("ln -f #{archivefile} #{File.join(targetdir,basename)}")
          link=true
        end


        case extname
          when ".gz", ".gzip"
            if File.extname(File.basename(basename,extname)) == ".tar"
              Lib::Shell.run("cd #{targetdir}; #{BIN_TAR} xzf #{basename}")
            else
              Lib::Shell.run("cd #{targetdir}; #{BIN_GUNZIP} #{basename}")
            end
          when ".bz2", "bzip2"
            if File.extname(File.basename(basename,extname)) == ".tar"
              Lib::Shell.run("cd #{targetdir}; #{BIN_TAR} xjf #{basename}")
            else
              Lib::Shell.run("cd #{targetdir}; #{BIN_BUNZIP2} #{basename}")
            end
          when ".zip"
            Lib::Shell.run("cd #{targetdir}; #{BIN_UNZIP} #{basename}")
          else
            raise "Format '#{File.extname(archivefile)}' not supported"
        end

        Lib::Shell.run("rm #{File.join(targetdir,basename)}") if link

        return targetdir
      end
    end

  end
end
