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
    @vnode = nil
    @vnodename = nil
  end

  def teardown
    super
  end

  def random_string(maxsize = 8)
    chars = [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
    size = rand(maxsize)
    return (0..size).map{ chars[rand(chars.length)] }.join
  end

  def init_daemon
    localaddr = '127.0.0.1'
    @daemon_d.pnode_init(localaddr)
  end

  def init_testvnode
    image  = 'file:///home/lsarzyniec/rootfs.tar.bz2'
    properties   = { 'image' => image }

    init_daemon
    @vnodename = 'testvnode'
    @daemon_d.vnode_create(@vnodename,properties)
    @vnode = @daemon_d.daemon_resources.get_vnode(@vnodename)
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

  def test_vnode_start
    init_testvnode()

    #No problems
    @daemon_d.vnode_start(@vnodename)
    assert_equal(@vnode.status,Wrekavoc::Resource::VNode::Status::STARTED)

    #Start an undefined vnode
    assert_raise(Wrekavoc::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_start(random_string)
    }
    
  end

  def test_vnode_stop
    init_testvnode()

    #No problems
    @daemon_d.vnode_stop(@vnodename)
    assert_equal(@vnode.status,Wrekavoc::Resource::VNode::Status::STOPPED)

    #Stop an undefined vnode
    assert_raise(Wrekavoc::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_stop(random_string)
    }
  end

  def test_viface_create
    init_testvnode()
    name = 'if0'

    #No problems
    @daemon_d.viface_create(@vnodename,name)
    viface = @vnode.get_viface_by_name(name)
    assert_not_nil(viface)
    assert_equal(viface.name,name)

    #Recreate with the same name
    assert_raise(Wrekavoc::Lib::AlreadyExistingResourceError) {
      @daemon_d.viface_create(@vnodename,name)
    }

    assert_raise(Wrekavoc::Lib::ResourceNotFoundError) {
      @daemon_d.viface_create(random_string,name)
    }

    viface = @vnode.get_viface_by_name(random_string)
    assert_nil(viface)
  end

  def test_vnetwork_create
    name = 'vnetwork'
    address = '10.144.8.0/24'

    #No problems
    init_daemon
    @daemon_d.vnetwork_create(name,address)
    vnetwork = @daemon_d.daemon_resources.get_vnetwork_by_name(name)
    assert_not_nil(vnetwork)
    vnetwork = @daemon_d.daemon_resources.get_vnetwork_by_address(address)
    assert_not_nil(vnetwork)
    assert_equal(vnetwork.name,name)
    assert_equal(vnetwork.address.to_string,address)

    #Recreate with the same address
    assert_raise(Wrekavoc::Lib::AlreadyExistingResourceError) {
      @daemon_d.vnetwork_create('newname',address)
    }

    #Recreate with the same name
    assert_raise(Wrekavoc::Lib::AlreadyExistingResourceError) {
      @daemon_d.vnetwork_create(name,'127.0.0.0/24')
    }

    #Create with a wrong address
    address = 'abcdef'
    assert_raise(Wrekavoc::Lib::InvalidParameterError) {
      @daemon_d.vnetwork_create(name,address)
    }
    vnetwork = @daemon_d.daemon_resources.get_vnetwork_by_address(address)
    assert_nil(vnetwork)
  end
end
