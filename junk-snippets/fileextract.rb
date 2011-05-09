$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'wrekavoc'

puts Wrekavoc::Lib::FileManager.extract("/tmp/rootfs.tar.bz2","/tmp/test1/")
puts Wrekavoc::Lib::FileManager.extract("/tmp/rootfs.tar.bz2","/tmp/test2/")
