$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'

daemon = Distem::NetAPI::Server.new
daemon.run
