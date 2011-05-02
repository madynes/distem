$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'wrekavoc/netapi/client'

cl = Wrekavoc::NetAPI::Client.new("127.0.0.1")
puts cl.vnode_create("127.0.0.1","toto","")
