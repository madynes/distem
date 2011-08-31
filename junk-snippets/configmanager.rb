$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'

pnode = Wrekavoc::Resource::PNode.new("127.0.0.1")
vnode = Wrekavoc::Resource::VNode.new(pnode,"mynode1","file:///tmp/vm-squeeze.tar.bz2")
viface = Wrekavoc::Resource::VIface.new("if0","127.0.0.1")
vnode.add_viface(viface)
cm = Wrekavoc::Node::ConfigManager.new
cm.vnode_add(vnode)
viface = Wrekavoc::Resource::VIface.new("if1","127.0.0.2")
vnode.add_viface(viface)
cm.vnode_configure(vnode)
