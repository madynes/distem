require 'wrekavoc'
require 'uri'
require 'digest/sha2'

module Wrekavoc
  module Lib

    class FileManager
      PATH_DEFAULT_DOWNLOAD="/tmp/"
      PATH_DEFAULT_CACHE="/tmp/extractcache/"

      BIN_TAR="tar"
      BIN_GUNZIP="gunzip"
      BIN_BUNZIP2="bunzip2"
      BIN_UNZIP="unzip"

      @@extractcache = []
      
      # Returns a path to the file on the local machine
      def self.download(uri_str,dir=PATH_DEFAULT_DOWNLOAD)
        uri = URI.parse(URI.decode(uri_str))
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
        
        unless File.exists?(PATH_DEFAULT_CACHE)
          Lib::Shell.run("mkdir -p #{PATH_DEFAULT_CACHE}")
        end

        basename = File.basename(archivefile)
        extname = File.extname(archivefile)
        filehash = file_hash(archivefile)
        cachedir = File.join(PATH_DEFAULT_CACHE,filehash)

        if targetdir.empty?
          targetdir = File.dirname(archivefile)
        else
          unless File.exists?(targetdir)
            Lib::Shell.run("mkdir -p #{targetdir}")
          end
        end

        unless @@extractcache.include?(filehash)
          if File.exists?(cachedir)
            Lib::Shell.run("rm -R #{cachedir}")
          end
          Lib::Shell.run("mkdir -p #{cachedir}")
          Lib::Shell.run("ln -sf #{archivefile} #{File.join(cachedir,basename)}")

          case extname
            when ".gz", ".gzip"
              if File.extname(File.basename(basename,extname)) == ".tar"
                Lib::Shell.run("cd #{cachedir}; #{BIN_TAR} xzf #{basename}")
              else
                Lib::Shell.run("cd #{cachedir}; #{BIN_GUNZIP} #{basename}")
              end
            when ".bz2", "bzip2"
              if File.extname(File.basename(basename,extname)) == ".tar"
                Lib::Shell.run("cd #{cachedir}; #{BIN_TAR} xjf #{basename}")
              else
                Lib::Shell.run("cd #{cachedir}; #{BIN_BUNZIP2} #{basename}")
              end
            when ".zip"
              Lib::Shell.run("cd #{cachedir}; #{BIN_UNZIP} #{basename}")
            else
              raise "Format '#{File.extname(archivefile)}' not supported"
          end

          Lib::Shell.run("rm #{File.join(cachedir,basename)}")
          @@extractcache << filehash
        end

        Lib::Shell.run("cp -Rf #{File.join(cachedir,'*')} #{targetdir}")

        return targetdir
      end

      def self.file_hash(filename)
        File.basename(filename) + "-" + File.stat(filename).size.to_s \
          + "-" +Digest::SHA256.file(filename).hexdigest
      end
    end

  end
end
