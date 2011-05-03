$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'wrekavoc'

puts Wrekavoc::Lib::FileManager.extract(File.join(File.dirname(__FILE__),"..","pkg","wrekavoc-0.1.tar.gz"),"/tmp/test/")
