require 'client'

cl = NetAPI::Client.new("127.0.0.1")
puts cl.vnode_create("127.0.0.1","toto")
