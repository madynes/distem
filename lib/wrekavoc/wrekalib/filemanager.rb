require 'wrekavoc'
require 'uri'
require 'digest/sha2'

module Wrekavoc
  module Lib

    class FileManager
      MAX_SIMULTANEOUS_EXTRACT = 8

      PATH_CURRENT=File.expand_path(File.dirname(__FILE__))
      PATH_WREKAVOC_BIN=File.expand_path('../../../bin/',PATH_CURRENT)
      PATH_WREKAVOC_LOGS=File.expand_path('../../../logs/',PATH_CURRENT)

      PATH_DEFAULT_DOWNLOAD="/tmp/wrekavoc/downloads/"
      PATH_DEFAULT_CACHE="/tmp/wrekavoc/extractcache/"
      PATH_DEFAULT_COMPRESS="/tmp/wrekavoc/files/"

      BIN_TAR="tar"
      BIN_GUNZIP="gunzip"
      BIN_BUNZIP2="bunzip2"
      BIN_UNZIP="unzip"

      @@initcachelock = {}
      @@cachelock = {}
      
      # Returns a path to the file on the local machine
      def self.download(uri_str,dir=PATH_DEFAULT_DOWNLOAD)
        begin
          uri = URI.parse(URI.decode(uri_str))
        rescue URI::InvalidURIError
          raise Lib::InvalidParameterError, uri_str
        end

        ret = ""
        
        case uri.scheme
          when "file"
            ret = uri.path
            raise Lib::ResourceNotFoundError, ret unless File.exists?(ret)
          else
            raise Lib::NotImplementedError, uri.scheme
        end

        return ret
      end

      def self.extract(archivefile,targetdir="")
        raise Lib::ResourceNotFoundError, archivefile \
          unless File.exists?(archivefile)
        
        if targetdir.empty?
          targetdir = File.dirname(archivefile)
        else
          unless File.exists?(targetdir)
            Lib::Shell.run("mkdir -p #{targetdir}")
          end
        end

        cachedir = cache_archive(archivefile)
        filehash = file_hash(archivefile)

        unless @@cachelock[filehash]
          @@cachelock[filehash] = Semaphore.new(MAX_SIMULTANEOUS_EXTRACT)
        end

        @@cachelock[filehash].synchronize {
          Lib::Shell.run("cp -Rf #{File.join(cachedir,'*')} #{targetdir}")
        }

        return targetdir
      end

      def self.extract!(archivefile,target_dir)
        raise Lib::ResourceNotFoundError, archivefile \
          unless File.exists?(archivefile)

        unless File.exists?(target_dir)
          Lib::Shell.run("mkdir -p #{target_dir}")
        end

        basename = File.basename(archivefile)
        extname = File.extname(archivefile)
        Lib::Shell.run("ln -sf #{archivefile} #{File.join(target_dir,basename)}")
        case extname
          when ".tar"
            Lib::Shell.run("cd #{target_dir}; #{BIN_TAR} xf #{basename}")
          when ".gz", ".gzip"
            if File.extname(File.basename(basename,extname)) == ".tar"
              Lib::Shell.run("cd #{target_dir}; #{BIN_TAR} xzf #{basename}")
            else
              Lib::Shell.run("cd #{target_dir}; #{BIN_GUNZIP} #{basename}")
            end
          when ".bz2", "bzip2"
            if File.extname(File.basename(basename,extname)) == ".tar"
              Lib::Shell.run("cd #{target_dir}; #{BIN_TAR} xjf #{basename}")
            else
              Lib::Shell.run("cd #{target_dir}; #{BIN_BUNZIP2} #{basename}")
            end
          when ".zip"
            Lib::Shell.run("cd #{target_dir}; #{BIN_UNZIP} #{basename}")
          else
            raise Lib::NotImplementedError, File.extname(archivefile)
        end

        Lib::Shell.run("rm #{File.join(target_dir,basename)}")
      end

      def self.cache_archive(archivefile)
        filehash = file_hash(archivefile)
        cachedir = File.join(PATH_DEFAULT_CACHE,filehash)

        if @@initcachelock[filehash]
          @@initcachelock[filehash].synchronize {}
        else
          @@initcachelock[filehash] = Mutex.new
          @@initcachelock[filehash].synchronize {
            if File.exists?(cachedir)
              Lib::Shell.run("rm -R #{cachedir}")
            end
            extract!(archivefile,cachedir)
          }
        end

        return cachedir
      end

      def self.compress(filepath)
        raise Lib::ResourceNotFoundError, filepath \
          unless File.exists?(filepath)
        unless File.exists?(PATH_DEFAULT_COMPRESS)
          Lib::Shell.run("mkdir -p #{PATH_DEFAULT_COMPRESS}")
        end

        basename = File.basename(filepath)
        respath = "#{File.join(PATH_DEFAULT_COMPRESS,basename)}.tar.gz"
        Lib::Shell.run("#{BIN_TAR} czf #{respath} -C #{filepath} .")
        
        return respath
      end

      def self.file_hash(filename)
        File.basename(filename) + "-" + File.stat(filename).size.to_s \
          + "-" +Digest::SHA256.file(filename).hexdigest
      end
    end

  end
end
