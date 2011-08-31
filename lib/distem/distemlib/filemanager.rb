require 'wrekavoc'
require 'uri'
require 'digest/sha2'

module Wrekavoc
  module Lib

    # Class that allow to manage files and archives (extracting, downloading, ...)
    class FileManager
      # The maximum simultaneous extracting task number
      MAX_SIMULTANEOUS_EXTRACT = 8

      PATH_CURRENT=File.expand_path(File.dirname(__FILE__)) # :nodoc:
      PATH_WREKAVOC_BIN=File.expand_path('../../../bin/',PATH_CURRENT) # :nodoc:
      PATH_WREKAVOC_LOGS=File.expand_path('../../../logs/',PATH_CURRENT) # :nodoc:

      # The directory used to store downloaded files
      PATH_DEFAULT_DOWNLOAD="/tmp/wrekavoc/downloads/"
      # The directory used to store archive extraction cache
      PATH_DEFAULT_CACHE="/tmp/wrekavoc/extractcache/"
      # The directory used to store compressed files
      PATH_DEFAULT_COMPRESS="/tmp/wrekavoc/files/"

      BIN_TAR="tar" # :nodoc:
      BIN_GUNZIP="gunzip" # :nodoc:
      BIN_BUNZIP2="bunzip2" # :nodoc:
      BIN_UNZIP="unzip" # :nodoc:

      @@initcachelock = {}
      @@cachelock = {}
      
      # Download a file using a specific protocol and store it on the local machine
      # ==== Attributes
      # * +uri_str+ The URI of the file to download
      # * +dir+ The directory to save the file to
      # ==== Returns
      # String value describing the path to the downloaded file on the local machine
      # ==== Exceptions
      # * +InvalidParameterError+ if the specified URI is not valid
      # * +ResourceNotFoundError+ if can't reach the specified file
      # * +NotImplementedError+ if the protocol specified in the URI is not supported (atm only file:// is supported)
      #
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

      # Extract an archive file in the specified directory using a cache. The cache: if unarchiving two times the same archive, the unarchive cache is used to only have to copy files from the cache (no need to unarchive another time). Only MAX_SIMULTANEOUS_EXTRACT files can be extracted at the same time (semaphore).
      # ==== Attributes
      # * +archivefile+ The path to the archive file (String)
      # * +targetdir+ The directory to unarchive the file to
      # ==== Returns
      # String value describing the path to the directory (on the local machine) the file was unarchived to
      # ==== Exceptions
      # * +ResourceNotFoundError+ if can't reach the specified archive file
      # * +NotImplementedError+ if the archive file format is not supported (available: tar, gzip, bzip, zip, (tgz,...))
      #
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

      # Extract an archive file in the specified directory without using the cache and the MAX_SIMULTANEOUS_EXTRACT limitation.
      # ==== Attributes
      # * +archivefile+ The path to the archive file (String)
      # * +targetdir+ The directory to unarchive the file to
      # ==== Returns
      # String value describing the path to the directory (on the local machine) the file was unarchived to
      # ==== Exceptions
      # * +ResourceNotFoundError+ if can't reach the specified archive file
      # * +NotImplementedError+ if the archive file format is not supported (available: tar, gzip, bzip, zip, (tgz,...))
      #
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

      # Cache an archive fine in the cache. Only one file can be cached at the same time (mutex).
      # ==== Attributes
      # * +archivefile+ The path to the archive file (String)
      # ==== Returns
      # String value describing the path to the directory (on the local machine) the file was cached to
      # 
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

      # Compress a file using TGZ archive format.
      # ==== Attributes
      # * +filepath+ The path to the file (String)
      # ==== Returns
      # String value describing the path to the directory (on the local machine) the generated archive file is store to
      # 
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

      # Get a "unique" file identifier from a specific file
      # ==== Attributes
      # * +filename+ The path to the file (String)
      # ==== Returns
      # String value describing the "unique" hash
      #
      def self.file_hash(filename)
        File.basename(filename) + "-" + File.stat(filename).size.to_s \
          + "-" +Digest::SHA256.file(filename).hexdigest
      end
    end

  end
end
