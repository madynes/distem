$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'wrekavoc'

daemon = Wrekavoc::NetAPI::Server.new
daemon.run
