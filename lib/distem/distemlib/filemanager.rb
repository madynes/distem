# -*- coding: utf-8 -*-
require 'thread'
require 'uri'
require 'cgi'
require 'digest/sha2'

module Distem
  module Lib

    # Class that allow to manage files and archives (extracting, downloading, ...)
    class FileManager
      # The directory used to store downloaded files
      PATH_DEFAULT_DOWNLOAD='/tmp/distem/downloads/'
      # The directory used to store archive extraction cache
      PATH_DEFAULT_CACHE='/tmp/distem/extractcache/'
      # The directory used to store compressed files
      PATH_DEFAULT_COMPRESS='/tmp/distem/files/'

      BIN_TAR='tar' # :nodoc:

      @@lock = Mutex.new # :nodoc:
      @@hashcache = {}
      @@archivecache = [] # :nodoc:
      @@cowcache = [] # :nodoc:

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
          uri = URI.parse(CGI.unescape(uri_str))
        rescue URI::InvalidURIError
          raise Lib::InvalidParameterError, uri_str
        end

        ret = ""

        case uri.scheme
          when "file"
            ret = uri.path
            raise Lib::ResourceNotFoundError, ret unless File.exist?(ret)
          else
            raise Lib::NotImplementedError, uri.scheme
        end

        return ret
      end

      # Extract an archive file in the specified directory using a cache. The cache: if unarchiving two times the same archive, the unarchive cache is used to only have to copy files from the cache (no need to unarchive another time).
      # ==== Attributes
      # * +archivefile+ The path to the archive file (String)
      # * +targetdir+ The directory to unarchive the file to
      # ==== Returns
      # String value describing the path to the directory (on the local machine) the file was unarchived to
      # ==== Exceptions
      # * +ResourceNotFoundError+ if can't reach the specified archive file
      # * +NotImplementedError+ if the archive file format is not supported (available: tar, gzip, bzip, zip, (tgz,...))
      #
      def self.extract(archivefile,targetdir="",override=true,cow=false)
        raise Lib::ResourceNotFoundError, archivefile unless File.exist?(archivefile)

        if targetdir.empty?
          targetdir = File.dirname(archivefile)
        end

        filehash = file_hash(archivefile)

        @@lock.synchronize {
          cachedir,new = cache_archive(archivefile,filehash,cow)
          exists = File.exist?(targetdir)
          if !exists or override or new
            Lib::Shell.run("rm -Rf #{targetdir}") if exists
            if cow
              Lib::Shell.run("btrfs subvolume snapshot #{cachedir} #{targetdir}")
            else
              Lib::Shell.run("mkdir -p #{targetdir}")
              Lib::Shell.run("cp -af #{File.join(cachedir,'*')} #{targetdir}")
            end
          end
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
          unless File.exist?(archivefile)

        unless File.exist?(target_dir)
          Lib::Shell.run("mkdir -p #{target_dir}")
        end

        basename = File.basename(archivefile)
        link = File.join(target_dir, basename)
        Lib::Shell.run("ln -sf #{archivefile} #{link}")
        Lib::Shell.run("(cd #{target_dir} && #{BIN_TAR} xf #{basename})")
        Lib::Shell.run("rm #{link}")
      end

      # Cache an archive fine in the cache. Only one file can be cached at the same time (mutex).
      # ==== Attributes
      # * +archivefile+ The path to the archive file (String)
      # * +filehash+ The hash of the archive file (String)
      # ==== Returns
      # String value describing the path to the directory (on the local machine) the file was cached to
      #
      def self.cache_archive(archivefile,filehash,cow)
        Lib::Shell.run("mkdir -p #{PATH_DEFAULT_CACHE}") if !File.exist?(PATH_DEFAULT_CACHE)
        cachedir = File.join(PATH_DEFAULT_CACHE,filehash)
        newcache = false

        unless @@archivecache.include?(filehash)
          @@archivecache << filehash
          if File.exist?(cachedir)
            Lib::Shell.run("rm -R #{cachedir}")
          end
          if cow
            Lib::Shell.run("btrfs subvolume create #{cachedir}")
            @@cowcache << cachedir
          end
          extract!(archivefile,cachedir)
          newcache = true
        end
        return cachedir,newcache
      end


      def self.clean_cache
        @@lock.synchronize {
          @@cowcache.each { |path|
            Lib::Shell.run("btrfs subvolume delete #{path}")
          }
        }
      end

      # Compress a file using TGZ archive format.
      # ==== Attributes
      # * +filepath+ The path to the file (String)
      # ==== Returns
      # String value describing the path to the directory (on the local machine) the generated archive file is store to
      #
      def self.compress(filepath)
        raise Lib::ResourceNotFoundError, filepath \
          unless File.exist?(filepath)
        unless File.exist?(PATH_DEFAULT_COMPRESS)
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
        ret = nil
        @@lock.synchronize do
          unless @@hashcache[filename] and @@hashcache[filename][:mtime] == (mtime= File.mtime(filename))
            unless @@hashcache[filename]
              mtime = File.mtime(filename) unless mtime
              sha256 = `sha256sum #{filename}|cut -f1 -d' '`.chomp
              # if sha256sum is not functional, we use the slower Ruby version
              if (sha256 == '')
                sha256 = Digest::SHA256.file(filename).hexdigest
              end
              @@hashcache[filename] = {
                :mtime => mtime,
                :hash => "#{File.basename(filename)}-#{mtime.to_i.to_s}-#{File.stat(filename).size.to_s}-#{sha256}"
              }
            end
          end
          ret = @@hashcache[filename][:hash]
        end

        return ret
      end
    end

  end
end
