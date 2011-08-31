$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'

puts Wrekavoc::Lib::FileManager.download("file:///etc/hosts");
