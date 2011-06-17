$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'wrekavoc'
require 'test/unit'

class TestWrekavocDaemonWrekaDaemon < Test::Unit::TestCase
  def setup
    super
    @daemon_d = Wrekavoc::Daemon::WrekaDaemon.new( \
      Wrekavoc::Daemon::WrekaDaemon::MODE_DAEMON \
    )
    @daemon_n = Wrekavoc::Daemon::WrekaDaemon.new( \
      Wrekavoc::Daemon::WrekaDaemon::MODE_NODE \
    )
  end

  def teardown
    super
  end

  def random_string(maxsize = 8)
    chars = [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
    size = rand(maxsize)
    return (0..size).map{ chars[rand(chars.length)] }.join
  end

  def test_pnode_init
    localaddr = '127.0.0.1'
    tmpaddr = ''

    ### Daemon mode tests
  
    #No problems
    @daemon_d.pnode_init(localaddr)
    pnode = @daemon_d.daemon_resources.get_pnode_by_address(localaddr)
    assert_not_nil(pnode)
    assert_equal(localaddr,pnode.address.to_s)
    assert_equal(pnode.status,Wrekavoc::Resource::PNode::STATUS_RUN)

    #Reinitialization
    assert_raise(Wrekavoc::Lib::AlreadyExistingResourceError) {
      @daemon_d.pnode_init(localaddr)
    }
    pnode = @daemon_d.daemon_resources.get_pnode_by_address(localaddr)
    assert_not_nil(pnode)

    #Invalid node hostname
    tmpaddr = random_string
    assert_raise(Wrekavoc::Lib::InvalidParameterError) {
      @daemon_d.pnode_init(tmpaddr)
    }
    pnode = @daemon_d.daemon_resources.get_pnode_by_address(tmpaddr)
    assert_nil(pnode)

    #Unreachable address
    tmpaddr = '255.255.255.255'
    assert_raise(Wrekavoc::Lib::UnreachableResourceError) {
      @daemon_d.pnode_init(tmpaddr)
    }
    pnode = @daemon_d.daemon_resources.get_pnode_by_address(tmpaddr)
    assert_nil(pnode)

    ### Node mode tests

    #No problems
    @daemon_n.pnode_init(localaddr)
    assert_equal(@daemon_n.node_config.pnode.status,
      Wrekavoc::Resource::PNode::STATUS_RUN
    )
  end

  def test_vnode_create
    localaddr = '127.0.0.1'
    name   = 'node1'
    name2  = 'node2'
    name3  = 'node3'
    image  = 'file:///home/lsarzyniec/rootfs.tar.bz2'
    properties   = { 'image' => image }
    properties2  = { 'image' => image, 'target' => localaddr }

    ### Daemon mode test
    
    #Creation without having any pnode available
    assert_raise(Wrekavoc::Lib::UnavailableResourceError) {
      @daemon_d.vnode_create(name,properties)
    }

    #No problems (no target specified)
    @daemon_d.pnode_init(localaddr)
    pnode = @daemon_d.daemon_resources.get_pnode_by_address(localaddr)
    @daemon_d.vnode_create(name,properties)
    vnode = @daemon_d.daemon_resources.get_vnode(name)
    assert_not_nil(vnode)
    assert_equal(vnode.name,name)
    assert_equal(vnode.host,pnode)
    assert_equal(vnode.image,image)
    assert_equal(vnode.gateway,false)
    assert_equal(vnode.status,Wrekavoc::Resource::VNode::Status::STOPPED)

    #Recreate with the same name
    assert_raise(Wrekavoc::Lib::AlreadyExistingResourceError) {
      @daemon_d.vnode_create(name,properties)
    }
    vnode = @daemon_d.daemon_resources.get_vnode(name)
    assert_not_nil(vnode)

    #No problems (target specified)
    @daemon_d.vnode_create(name2,properties2)
    vnode2 = @daemon_d.daemon_resources.get_vnode(name2)
    assert_equal(vnode2.name,name2)
    assert_equal(vnode2.host,pnode)

    #Invalid target name
    properties2['target'] = random_string
    assert_raise(Wrekavoc::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_create(name3,properties2)
    }
    vnode3 = @daemon_d.daemon_resources.get_vnode(name3)
    assert_nil(vnode3)

    #No image specified
    assert_raise(Wrekavoc::Lib::MissingParameterError) {
      @daemon_d.vnode_create(name3,{})
    }
    vnode3 = @daemon_d.daemon_resources.get_vnode(name3)
    assert_nil(vnode3)

    #Invalid image path
    properties['image'] = ':.'
    assert_raise(Wrekavoc::Lib::InvalidParameterError) {
      @daemon_d.vnode_create(name3,properties)
    }
    vnode3 = @daemon_d.daemon_resources.get_vnode(name3)
    assert_nil(vnode3)

    #Invalid path to the image
    properties['image'] = 'file:///test/test/test'
    assert_raise(Wrekavoc::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_create(name3,properties)
    }
    vnode3 = @daemon_d.daemon_resources.get_vnode(name3)
    assert_nil(vnode3)
    
    #Protocol not supported
    properties['image'] = 'http://public.nancy.grid5000.fr/~lsarzyniec/rootfs.tar.bz2'
    assert_raise(Wrekavoc::Lib::NotImplementedError) {
      @daemon_d.vnode_create(name3,properties)
    }
    vnode3 = @daemon_d.daemon_resources.get_vnode(name3)
    assert_nil(vnode3)

    #File format not supported
    properties['image'] = 'file:///home/lsarzyniec/rootfs.7zip'
    assert_raise(Wrekavoc::Lib::NotImplementedError) {
      @daemon_d.vnode_create(name3,properties)
    }
    vnode3 = @daemon_d.daemon_resources.get_vnode(name3)
    assert_nil(vnode3)

  end
end
