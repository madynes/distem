$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'wrekavoc'

pnode = Wrekavoc::Resource::PNode.new("127.0.0.1")
vnode = Wrekavoc::Resource::VNode.new(pnode,"mynode1","file:///tmp/vm-squeeze.tar.bz2")
cm = Wrekavoc::Node::ConfigManager.new
cm.vnode_add(vnode)
