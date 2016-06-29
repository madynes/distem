require 'spec_helper'

describe Distem::Resource::VPlatform do

  before :all do

    # Distem installation
    @vplatform = Distem::Resource::VPlatform.new
    @vnetwork = []
    @vnetwork.push(Distem::Resource::VNetwork.new("10.144.0.0/22", "vnet", 1,""))
    @vnetwork.push(Distem::Resource::VNetwork.new("10.150.0.0/22", "vnet2", 1,""))
    @dot_file = Tempfile.new('test_dotfile').path
  end

  it "creates an empty DOT file" do
    expect{@vplatform.vnodes_to_dot(@dot_file)}.not_to raise_error
  end

  it "adds a vnode to the vplatform" do
    vnode = Distem::Resource::VNode.new("node1","")
    vnode.add_vcpu(1,1,0)
    @vplatform.add_vnode(vnode)
  end

  it "gets a vnode object" do
    expect(@vplatform.get_vnode("node1")).to be_an_instance_of(Distem::Resource::VNode)
  end


  it "adds a vnode with a network interface" do
    vnode = Distem::Resource::VNode.new("node2","")
    vnode.add_vcpu(1,1,0)
    viface = Distem::Resource::VIface.new("if-adm",vnode,{})
    vnode.add_viface(viface)
    @vnetwork[0].add_vnode(vnode,viface,"10.144.0.1")
    @vplatform.add_vnode(vnode)
  end

  it "adds a vnode with two network interfaces" do

   vnode = Distem::Resource::VNode.new("node3","")
    vnode.add_vcpu(1,1,0)
    (1..2).each do |n|
      viface = Distem::Resource::VIface.new("if#{n}",vnode,{})
      viface.voutput = Distem::Resource::VIface::VTraffic.new(viface,
                                                              Distem::Resource::VIface::VTraffic::Direction::OUTPUT,{"bandwidth" =>{"rate" => "#{n}00mbps"}})
      vnode.add_viface(viface)
      @vnetwork[0].add_vnode(vnode,viface,"10.144.1.#{n}") if n==1
      @vnetwork[1].add_vnode(vnode,viface,"10.150.1.#{n}") if n==2
    end
    @vplatform.add_vnode(vnode)
    # expect{@vplatform.vnodes_to_dot(@dot_file)}.not_to raise_error
  end

  it "adds another vnode" do
    vnode = Distem::Resource::VNode.new("node10","")
    vnode.add_vcpu(1,1,0)
    viface = Distem::Resource::VIface.new("if-adm",vnode,{})
    vnode.add_viface(viface)
    @vnetwork[1].add_vnode(vnode,viface,"10.150.0.1")
    @vplatform.add_vnode(vnode)
  end

  it "adds the vnetworks and generates DOT file" do
    expect{@vplatform.add_vnetwork(@vnetwork[0])}.not_to raise_error
    expect{@vplatform.add_vnetwork(@vnetwork[1])}.not_to raise_error
    expect{@vplatform.vnodes_to_dot(@dot_file)}.not_to raise_error
  end

  it "verifies the produced DOT file" do
    v_topo = GraphViz.parse(@dot_file)
    result = []
    v_topo.each_node do |node_name, node|
      node.each_attribute{ |attr_name,value|
        result.push(true) if value.to_s.delete('\\"') =="switch"
      }
    end
    expect(result.length).to be 2
  end

  it "loads a physical topology"  do
    expect(@vplatform.load_physical_topo("spec/input/physical-net.dot")).to be_an_instance_of(Hash)
  end

  it "raises an error related to a syntax problem on the DOT file"  do
    expect{@vplatform.load_physical_topo("spec/input/complex-physical-topo.dot")}.to raise_error(Distem::Lib::ParameterError)
  end


end
