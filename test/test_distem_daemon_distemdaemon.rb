$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'distem'
require 'test/unit'

class TestDistemDaemonDistemDaemon < Test::Unit::TestCase
  def setup
    super
    if not (ENV['DISTEM_RUN_TESTS_ANYWAY'] or `hostname --fqdn`.chomp =~ /grid5000.fr$/)
      puts "The distem test suite is destructive for the system it is being run on."
      puts "By default, it can only be run on Grid'5000 nodes."
      puts "If you really want to run the test suite, set the"
      puts "DISTEM_RUN_TESTS_ANYWAY environment variable."
      exit(1)
    end
    @daemon_d = Distem::Daemon::DistemDaemon.new( \
      Distem::Daemon::DistemDaemon::MODE_DAEMON \
    )
    @daemon_n = Distem::Daemon::DistemDaemon.new( \
      Distem::Daemon::DistemDaemon::MODE_NODE \
    )
    @vnode = nil
    @vnodename = nil
  end

  def teardown
    super
    localaddr = '127.0.0.1'
    #@daemon_d.pnode_quit(localaddr)
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
    @vnode = @daemon_d.vnode_create(@vnodename,properties)
    return @vnode
  end

  def test_pnode_init
    localaddr = '127.0.0.1'
    tmpaddr = ''

    ### Daemon mode tests
  
    #No problems
    pnode = @daemon_d.pnode_init(localaddr)
    assert_not_nil(pnode)
    assert_equal(localaddr,pnode.address.to_s)
    assert_equal(pnode.status,Distem::Resource::PNode::STATUS_RUN)

    #Reinitialization
    assert_raise(Distem::Lib::AlreadyExistingResourceError) {
      @daemon_d.pnode_init(localaddr)
    }
    assert_not_nil(@daemon_d.pnode_get(localaddr))

    #Invalid node hostname
    tmpaddr = random_string
    assert_raise(Distem::Lib::InvalidParameterError) {
      @daemon_d.pnode_init(tmpaddr)
    }

    #Unreachable address
    tmpaddr = '255.255.255.255'
    assert_raise(Distem::Lib::UnreachableResourceError) {
      @daemon_d.pnode_init(tmpaddr)
    }
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.pnode_get(tmpaddr)
    }

    ### Node mode tests

    #No problems
    pnode = @daemon_n.pnode_init(localaddr)
    assert_not_nil(pnode)
    assert_equal(true,Distem::Lib::NetTools.localaddr?(pnode.address.to_s))
    assert_equal(pnode.status,Distem::Resource::PNode::STATUS_RUN)
  end

  def test_pnode_get
    localaddr = '127.0.0.1'

    ### Daemon mode tests

    #No problems
    pnode = @daemon_d.pnode_init(localaddr)
    assert_not_nil(pnode)
    pnodeget = @daemon_d.pnode_get(localaddr)
    assert_not_nil(pnodeget)
    assert_equal(pnode,pnodeget)

    #Using hostname
    pnodeget = @daemon_d.pnode_get('localhost')
    assert_not_nil(pnodeget)
    assert_equal(pnode,pnodeget)

    #Invalid hostname
    tmpaddr = random_string
    assert_raise(Distem::Lib::InvalidParameterError) {
      @daemon_d.pnode_get(tmpaddr)
    }

    #Non existing node
    tmpaddr = '255.255.255.255'
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.pnode_get(tmpaddr)
    }
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
    assert_raise(Distem::Lib::UnavailableResourceError) {
      @daemon_d.vnode_create(name,properties)
    }

    #No problems (no target specified)
    @daemon_d.pnode_init(localaddr)
    pnode = @daemon_d.daemon_resources.get_pnode_by_address(localaddr)
    vnode = @daemon_d.vnode_create(name,properties)
    assert_not_nil(vnode)
    assert_equal(vnode.name,name)
    assert_equal(vnode.host,pnode)
    assert_equal(vnode.image,image)
    assert_equal(vnode.gateway,false)
    assert_equal(vnode.status,Distem::Resource::VNode::Status::STOPPED)

    #Recreate with the same name
    assert_raise(Distem::Lib::AlreadyExistingResourceError) {
      @daemon_d.vnode_create(name,properties)
    }
    assert_not_nil(@daemon_d.vnode_get(name))

    #No problems (target specified)
    @daemon_d.vnode_create(name2,properties2)
    vnode2 = @daemon_d.daemon_resources.get_vnode(name2)
    assert_equal(vnode2.name,name2)
    assert_equal(vnode2.host,pnode)

    #Invalid target name
    properties2['target'] = random_string
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_create(name3,properties2)
    }
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_get(name3)
    }

    #No image specified
    assert_raise(Distem::Lib::MissingParameterError) {
      @daemon_d.vnode_create(name3,{})
    }
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_get(name3)
    }

    #Invalid image path
    properties['image'] = ':.'
    assert_raise(Distem::Lib::InvalidParameterError) {
      @daemon_d.vnode_create(name3,properties)
    }
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_get(name3)
    }

    #Invalid path to the image
    properties['image'] = 'file:///test/test/test'
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_create(name3,properties)
    }
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_get(name3)
    }
    
    #Protocol not supported
    properties['image'] = 'http://public.nancy.grid5000.fr/~lsarzyniec/rootfs.tar.bz2'
    assert_raise(Distem::Lib::NotImplementedError) {
      @daemon_d.vnode_create(name3,properties)
    }
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_get(name3)
    }

    #File format not supported
    properties['image'] = 'file:///home/lsarzyniec/rootfs.7zip'
    assert_raise(Distem::Lib::NotImplementedError) {
      @daemon_d.vnode_create(name3,properties)
    }
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_get(name3)
    }
  end

  def test_vnode_set_status
    init_testvnode()

    #No problems (start)
    status = Distem::Resource::VNode::Status::RUNNING
    @daemon_d.vnode_set_status(@vnodename,status)
    assert_equal(@vnode.status,status)

    #No problems (stop)
    status = Distem::Resource::VNode::Status::STOPPED
    @daemon_d.vnode_set_status(@vnodename,status)
    assert_equal(@vnode.status,status)

    #Not authorized status
    status = Distem::Resource::VNode::Status::STOPING
    assert_raise(Distem::Lib::InvalidParameterError) {
      @daemon_d.vnode_set_status(@vnodename,status)
    }
    assert_equal(@vnode.status,Distem::Resource::VNode::Status::STOPPED)

    #Non existing vnode
    status = Distem::Resource::VNode::Status::STOPPED
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_set_status(random_string,status)
    }
  end

  def test_vnode_start
    init_testvnode()

    #No problems
    @daemon_d.vnode_start(@vnodename)
    assert_equal(@vnode.status,Distem::Resource::VNode::Status::RUNNING)

    #Start an undefined vnode
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_start(random_string)
    }
    
  end

  def test_vnode_stop
    init_testvnode()

    #No problems
    @daemon_d.vnode_stop(@vnodename)
    assert_equal(@vnode.status,Distem::Resource::VNode::Status::STOPPED)

    #Stop an undefined vnode
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnode_stop(random_string)
    }
  end

  def test_viface_create
    init_testvnode()
    name = 'if0'

    #No problems
    viface = @daemon_d.viface_create(@vnodename,name)
    assert_not_nil(viface)
    assert_equal(viface.name,name)
    assert_nil(viface.vnetwork)

    #Recreate with the same name
    assert_raise(Distem::Lib::AlreadyExistingResourceError) {
      @daemon_d.viface_create(@vnodename,name)
    }
    assert_not_nil(@daemon_d.viface_get(@vnodename,name))

    #Invalid vnode name
    tmpname = random_string
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.viface_create(tmpname,name)
    }
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.viface_get(tmpname,name)
    }
  end

  def test_viface_get
    init_testvnode()
    name = 'if0'

    #No problems
    viface = @daemon_d.viface_create(@vnodename,name)
    assert_not_nil(viface)
    vifaceget = @daemon_d.viface_get(@vnodename,name)
    assert_not_nil(vifaceget)
    assert_equal(viface,vifaceget)

    #Invalid vnode name
    tmpname = random_string
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.viface_get(tmpname,name)
    }

    #Invalid viface name
    tmpname = random_string
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.viface_get(@vnodename,tmpname)
    }
  end


  def test_vnetwork_create
    name = 'vnetwork'
    address = '10.144.8.0/24'

    #No problems
    init_daemon
    vnetwork = @daemon_d.vnetwork_create(name,address)
    assert_not_nil(vnetwork)
    assert_equal(vnetwork.name,name)
    assert_equal(vnetwork.address.to_string,address)

    #Recreate with the same address
    tmpname = 'newname'
    assert_raise(Distem::Lib::AlreadyExistingResourceError) {
      @daemon_d.vnetwork_create(tmpname,address)
    }
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnetwork_get(tmpname)
    }

    #Recreate with the same name
    assert_raise(Distem::Lib::AlreadyExistingResourceError) {
      @daemon_d.vnetwork_create(name,'127.0.0.0/24')
    }

    #Create with a wrong address
    tmpname = 'wrongaddr'
    address = 'abcdef'
    assert_raise(Distem::Lib::InvalidParameterError) {
      @daemon_d.vnetwork_create(tmpname,address)
    }
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnetwork_get(tmpname)
    }
  end

  def test_vnetwork_get
    init_daemon
    vnetworkname = 'vnetwork'

    #No problems
    vnetwork = @daemon_d.vnetwork_create(vnetworkname,'10.144.8.0/24')
    assert_not_nil(vnetwork)
    vnetworkget = @daemon_d.vnetwork_get(vnetworkname)
    assert_not_nil(vnetworkget)
    assert_equal(vnetwork,vnetworkget)

    #Non existing vnetwork
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.vnetwork_get(random_string)
    }
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
    viface = @daemon_d.viface_create(vnode.name,vifacename)
    viface2 = @daemon_d.viface_create(vnode2.name,vifacename)
    viface3 =@daemon_d.viface_create(vnode3.name,vifacename)
    vnetwork = @daemon_d.vnetwork_create(vnetworkname,'10.144.8.0/24')
    vnetwork2 = @daemon_d.vnetwork_create(vnetworkname2,'10.144.16.0/24')
    
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
    assert_raise(Distem::Lib::UnavailableResourceError) {
      @daemon_d.viface_attach(vnode3.name,vifacename,{'address' => vifaceaddress})
    }
    assert_nil(vnetwork.vnodes[vnode3])
    assert_nil(viface3.vnetwork)
    assert_equal(false,viface3.attached?)
    assert_equal(false,viface3.connected_to?(vnetwork))

    #Address do not fit in any vnetworks
    assert_raise(Distem::Lib::ResourceNotFoundError) {
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
    assert_raise(Distem::Lib::AlreadyExistingResourceError) {
      @daemon_d.viface_attach(vnode.name,vifacename,{'address' => vifaceaddress})
    }
    assert_equal(true,viface.attached?)
    assert_equal(true,viface.connected_to?(vnetwork))
    assert_equal(true,vnode.connected_to?(vnetwork))
    assert_equal(vnetwork,viface.vnetwork)
    assert_equal(vnetwork.vnodes[vnode],viface)

    assert_raise(Distem::Lib::AlreadyExistingResourceError) {
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

    assert_raise(Distem::Lib::AlreadyExistingResourceError) {
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
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.viface_attach(random_string,vifacename,{'vnetwork' => vnetworkname2})
    }
    assert_nil(vnetwork.vnodes[vnode])
    assert_nil(viface.vnetwork)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))

    #Invalid vifacename
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.viface_attach(vnode.name,random_string,{'vnetwork' => vnetworkname2})
    }
    assert_nil(vnetwork.vnodes[vnode])
    assert_nil(viface.vnetwork)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))

    #Invalid vnetworkname
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.viface_attach(vnode.name,vifacename,{'vnetwork' => random_string})
    }
    assert_nil(vnetwork.vnodes[vnode])
    assert_nil(viface.vnetwork)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))

    #Invalid address
    assert_raise(Distem::Lib::InvalidParameterError) {
      @daemon_d.viface_attach(vnode.name,vifacename,{'address' => random_string})
    }
    assert_nil(vnetwork.vnodes[vnode])
    assert_nil(viface.vnetwork)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))

    #Missing parameter
    assert_raise(Distem::Lib::MissingParameterError) {
      @daemon_d.viface_attach(vnode.name,vifacename,{})
    }
    assert_nil(vnetwork.vnodes[vnode])
    assert_nil(viface.vnetwork)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))
  end

  def test_viface_detach
    init_daemon
    vifacename = 'if0'
    vnetworkname = 'vnetwork'

    init_testvnode
    viface = @daemon_d.viface_create(@vnodename,vifacename)
    vnetwork = @daemon_d.vnetwork_create(vnetworkname,'10.144.8.0/24')
    
    assert_not_nil(viface)
    assert_not_nil(vnetwork)

    @daemon_d.viface_attach(@vnodename,vifacename,{'vnetwork' => vnetworkname})

    #No problems (automatic address)
    @daemon_d.viface_detach(@vnodename,vifacename)
    assert_equal(false,viface.attached?)
    assert_equal(false,viface.connected_to?(vnetwork))
    assert_equal(false,vnode.connected_to?(vnetwork))
    assert_nil(viface.vnetwork)
    assert_nil(vnetwork.vnodes[vnode])

    #Wrong node name
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.viface_detach(random_string,vifacename)
    }

    #Wrong iface name
    assert_raise(Distem::Lib::ResourceNotFoundError) {
      @daemon_d.viface_detach(@vnodename,random_string)
    }
  end

  def test_vroute_create
      init_daemon
      vifacename = 'if0'
      vifacename2 = 'if1'
      vnetworkname = 'vnetwork'
      vnetworkname2 = 'vnetwork2'

      vnode = init_testvnode(true,'1')
      vnode2 = init_testvnode(true,'2')
      vnodegw = init_testvnode(true,'3')
      viface = @daemon_d.viface_create(vnode.name,vifacename)
      viface2 = @daemon_d.viface_create(vnode2.name,vifacename)
      vifacegw1 = @daemon_d.viface_create(vnodegw.name,vifacename)
      vifacegw2 = @daemon_d.viface_create(vnodegw.name,vifacename2)
      vnetwork = @daemon_d.vnetwork_create(vnetworkname,'10.144.4.0/24')
      vnetwork2 = @daemon_d.vnetwork_create(vnetworkname2,'10.144.8.0/24')

      @daemon_d.viface_attach(vnode.name,vifacename,{'vnetwork' => vnetworkname})
      @daemon_d.viface_attach(vnode2.name,vifacename,{'vnetwork' => vnetworkname2})
      @daemon_d.viface_attach(vnodegw.name,vifacename2,{'vnetwork' => vnetworkname2})

      ### Daemon mode

      #Nodegw not connected on vnetwork1
      vroute = nil
      assert_raise(Distem::Lib::InvalidParameterError) {
        vroute = @daemon_d.vroute_create(vnetwork.name,vnetwork2.name,vnodegw.name)
      }
      assert_nil(vroute)
      assert_nil(vnetwork.get_vroute(vnetwork2))
      @daemon_d.viface_attach(vnodegw.name,vifacename,{'vnetwork' => vnetworkname})
      assert_equal(false,vnodegw.gateway)

      #No problems
      vroute = @daemon_d.vroute_create(vnetwork.name,vnetwork2.name,vnodegw.name)
      assert_not_nil(vroute)
      assert_equal(vnetwork,vroute.srcnet)
      assert_equal(vnetwork2,vroute.dstnet)
      assert_equal(vifacegw1.address.to_s,vroute.gw.to_s)
      assert_not_nil(vnetwork.get_vroute(vnetwork2))
      assert_not_nil(viface.vnetwork.get_vroute(vnetwork2))
      assert_equal(true,vnodegw.gateway)

      #Already existing ressource, no throws
      vroute = @daemon_d.vroute_create(vnetwork.name,vnetwork2.name,vnodegw.name)
      assert_not_nil(vroute)
      assert_equal(vnetwork,vroute.srcnet)
      assert_equal(vnetwork2,vroute.dstnet)
      assert_equal(vifacegw1.address.to_s,vroute.gw.to_s)

      #Invalid vnetwork name
      assert_raise(Distem::Lib::ResourceNotFoundError) {
        @daemon_d.vroute_create(random_string,vnetwork2.name,vnodegw.name)
      }
      assert_raise(Distem::Lib::ResourceNotFoundError) {
        @daemon_d.vroute_create(vnetwork.name,random_string,vnodegw.name)
      }

      #Invalid gateway name
      assert_raise(Distem::Lib::ResourceNotFoundError) {
        @daemon_d.vroute_create(vnetwork.name,vnetwork2.name,random_string)
      }
  end

  def test_pnode_quit
  end

  def test_vnode_remove
  end

  def test_viface_remove
  end

  def test_vnetwork_remove
  end
end
