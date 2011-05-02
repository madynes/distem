$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'wrekavoc'

ca = Wrekavoc::Node::Admin.new
ca.set_bridge
