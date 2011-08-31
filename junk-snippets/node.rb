$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'

ca = Wrekavoc::Node::Admin.new
ca.set_bridge
