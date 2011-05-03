$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'wrekavoc'

puts Wrekavoc::Lib::FileManager.download("file:///etc/hosts");
