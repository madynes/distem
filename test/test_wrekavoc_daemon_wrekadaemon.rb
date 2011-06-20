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

  def init_testvnode(initializeddaemon = false, sufix = "")
    image  = 'file:///home/lsarzyniec/rootfs.tar.bz2'
    properties   = { 'image' => image }

    init_daemon unless initializeddaemon
    @vnodename = 'testvnode' + sufix
    @daemon_d.vnode_create(@vnodename,properties)
    @vnode = @daemon_d.daemon_resources.get_vnode(@vnodename)
    return @vnode
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
    assert_nil(viface.vnetwork)

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

  def test_viface_attach
    init_daemon
    vifacename = 'if0'
    vnetworkname = 'vnetwork'
    vnetworkname2 = 'vnetwork2'
    vifaceaddress = '10.144.8.2'

    vnode = init_testvnode(true,'1')
    vnode2 = init_testvnode(true,'2')
    vnode3 = init_testvnode(true,'3')
    @daemon_d.viface_create(vnode.name,vifacename)
    viface = vnode.get_viface_by_name(vifacename)
    @daemon_d.viface_create(vnode2.name,vifacename)
    viface2 = vnode2.get_viface_by_name(vifacename)
    @daemon_d.viface_create(vnode3.name,vifacename)
    viface3 = vnode3.get_viface_by_name(vifacename)
    @daemon_d.vnetwork_create(vnetworkname,'10.144.8.0/24')
    vnetwork = @daemon_d.daemon_resources.get_vnetwork_by_name(vnetworkname)
    @daemon_d.vnetwork_create(vnetworkname2,'10.144.16.0/24')
    vnetwork2 = @daemon_d.daemon_resources.get_vnetwork_by_name(vnetworkname2)
    
    assert_not_nil(vnode)
    assert_not_nil(vnode2)
    assert_not_nil(vnode3)
    assert_not_nil(viface)
    assert_not_nil(viface2)
    assert_not_nil(viface3)
    assert_not_nil(vnetwork)
    assert_not_nil(vnetwork2)

    #No problems (automatic address)
    @daemon_d.viface_attach(vnode.name,vifacename,{'vnetwork' => vnetworkname})
    assert_equal('10.144.8.1',viface.address.to_s)
    assert_equal(true,viface.attached?)
    assert_equal(true,viface.connected_to?(vnetwork))
    assert_equal(true,vnode.connected_to?(vnetwork))
    assert_equal(vnetwork,viface.vnetwork)
    assert_equal(vnetwork.vnodes[vnode],viface)

    #No problems (manual address)
    @daemon_d.viface_attach(vnode2.name,vifacename,{'address' => vifaceaddress})
    assert_equal(vifaceaddress,viface2.address.to_s)
    assert_equal(true,viface2.attached?)
    assert_equal(true,viface2.connected_to?(vnetwork))
    assert_equal(true,vnode2.connected_to?(vnetwork))
    assert_equal(vnetwork,viface2.vnetwork)
    assert_equal(vnetwork.vnodes[vnode2],viface2)

    #Already used address
    assert_raise(Wrekavoc::Lib::UnavailableResourceError) {
      @daemon_d.viface_attach(vnode3.name,vifacename,{'address' => vifaceaddress})
    }
    assert_nil(vnetwork.vnodes[vnode3])
    assert_nil(viface3.vnetwork)
    assert_equal(false,viface3.attached?)
    assert_equal(false,viface3.connected_to?(vnetwork))

    #Address do not fit in any vnetworks
    assert_raise(Wrekavoc::Lib::ResourceNotFoundError) {
      @daemon_d.viface_attach(vnode3.name,vifacename,{'address' => '10.144.2.1'})
    }
    assert_nil(vnetwork.vnodes[vnode3])
    assert_nil(viface3.vnetwork)
    assert_equal(false,viface3.attached?)
    assert_equal(false,viface3.connected_to?(vnetwork))
    assert_equal(false,vnode3.connected_to?(vnetwork))
    assert_equal(false,vnode3.connected_to?(vnetwork))
    
    #Automatic address hop
    @daemon_d.viface_attach(vnode3.name,vifacename,{'vnetwork' => vnetworkname})
    assert_equal('10.144.8.3',viface3.address.to_s)
    assert_equal(true,viface3.attached?)
    assert_equal(true,viface3.connected_to?(vnetwork))
    assert_equal(true,vnode3.connected_to?(vnetwork))
    assert_equal(vnetwork,viface3.vnetwork)
    assert_equal(vnetwork.vnodes[vnode3],viface3)

    #Already attached viface
    assert_raise(Wrekavoc::Lib::AlreadyExistingResourceError) {
      @daemon_d.viface_attach(vnode.name,vifacename,{'address' => vifaceaddress})
    }
    assert_equal(true,viface.attached?)
    assert_equal(true,viface.connected_to?(vnetwork))
    assert_equal(true,vnode.connected_to?(vnetwork))
    assert_equal(vnetwork,viface.vnetwork)
    assert_equal(vnetwork.vnodes[vnode],viface)

    assert_raise(Wrekavoc::Lib::AlreadyExistingResourceError) {
      @daemon_d.viface_attach(vnode.name,vifacename,{'vnetwork' => vnetworkname})
    }
    assert_equal(true,viface.attached?)
    assert_equal(true,viface.connected_to?(vnetwork))
    assert_equal(true,vnode.connected_to?(vnetwork))
    assert_equal(vnetwork,viface.vnetwork)
    assert_equal(vnetwork.vnodes[vnode],viface)
    assert_equal(vnetwork, \
      @daemon_d.node_config.vplatform.get_vnetwork_by_name(vnetworkname) \
    ) # Only in daemon mode

    assert_raise(Wrekavoc::Lib::AlreadyExistingResourceError) {
      @daemon_d.viface_attach(vnode.name,vifacename,{'vnetwork' => vnetworkname2})
    }
    assert_equal(true,viface.attached?)
    assert_equal(true,viface.connected_to?(vnetwork))
    assert_equal(true,vnode.connected_to?(vnetwork))
    assert_equal(vnetwork,viface.vnetwork)
    assert_equal(vnetwork.vnodes[vnode],viface)

    #Remove vnode
    vnetwork.remove_vnode(vnode)
    assert_nil(vnetwork.vnodes[vnode])
    assert_nil(viface.vnetwork)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))
    
    #Invalid vnodename
    assert_raise(Wrekavoc::Lib::ResourceNotFoundError) {
      @daemon_d.viface_attach(random_string,vifacename,{'vnetwork' => vnetworkname2})
    }
    assert_nil(vnetwork.vnodes[vnode])
    assert_nil(viface.vnetwork)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))

    #Invalid vifacename
    assert_raise(Wrekavoc::Lib::ResourceNotFoundError) {
      @daemon_d.viface_attach(vnode.name,random_string,{'vnetwork' => vnetworkname2})
    }
    assert_nil(vnetwork.vnodes[vnode])
    assert_nil(viface.vnetwork)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))

    #Invalid vnetworkname
    assert_raise(Wrekavoc::Lib::ResourceNotFoundError) {
      @daemon_d.viface_attach(vnode.name,vifacename,{'vnetwork' => random_string})
    }
    assert_nil(vnetwork.vnodes[vnode])
    assert_nil(viface.vnetwork)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))

    #Invalid address
    assert_raise(Wrekavoc::Lib::InvalidParameterError) {
      @daemon_d.viface_attach(vnode.name,vifacename,{'address' => random_string})
    }
    assert_nil(vnetwork.vnodes[vnode])
    assert_nil(viface.vnetwork)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))

    #Missing parameter
    assert_raise(Wrekavoc::Lib::MissingParameterError) {
      @daemon_d.viface_attach(vnode.name,vifacename,{})
    }
    assert_nil(vnetwork.vnodes[vnode])
    assert_nil(viface.vnetwork)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))
  end
end
