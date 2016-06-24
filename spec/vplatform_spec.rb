require 'spec_helper'

describe Distem::Resource::VPlatform do

  before :all do

    # Distem installation
    @vplatform = Distem::Resource::VPlatform.new
    vnode = Distem::Resource::VNode.new("node1","")
    @vplatform.add_vnode(vnode)
    @dot_file = Tempfile.new('test_dotfile').path
  end

  it "gets a vnode object" do
    expect(@vplatform.get_vnode("node1")).to be_an_instance_of(Distem::Resource::VNode)
  end

  it "creates dot file 1 vnode" do
    expect{@vplatform.vnodes_to_dot(@dot_file)}.not_to raise_error
  end

  it "creates dot file 2 vnodes" do
    vnode = Distem::Resource::VNode.new("node2","")
    vnode.add_vcpu(1,1,0)
    @vplatform.add_vnode(vnode)
    expect{@vplatform.vnodes_to_dot(@dot_file)}.not_to raise_error
  end

  it "creates a dot file with network interfaces without bandwidth" do
    vnode = Distem::Resource::VNode.new("node3","")
    vnode.add_vcpu(1,1,0)
    viface = Distem::Resource::VIface.new("if-adm",vnode,{})
    vnode.add_viface(viface)
    @vplatform.add_vnode(vnode)
    expect{@vplatform.vnodes_to_dot(@dot_file)}.not_to raise_error
  end


  it "creates dot file 2 vnodes with network interface" do
    vnode = Distem::Resource::VNode.new("node4","")
    vnode.add_vcpu(1,1,0)
    viface = Distem::Resource::VIface.new("if1",vnode,{})
    viface.voutput = Distem::Resource::VIface::VTraffic.new(viface,
                                                    Distem::Resource::VIface::VTraffic::Direction::OUTPUT,{"bandwidth" =>{"rate" => "100mbps"}})
    vnode.add_viface(viface)
    @vplatform.add_vnode(vnode)
    expect{@vplatform.vnodes_to_dot(@dot_file)}.not_to raise_error
  end

  it "creates dot file 2 vnodes with multiple network interfaces network interfaces" do
    vnode = Distem::Resource::VNode.new("node5","")
    vnode.add_vcpu(1,1,0)
    (1..2).each do |n|
      viface = Distem::Resource::VIface.new("if#{n}",vnode,{})
      viface.voutput = Distem::Resource::VIface::VTraffic.new(viface,
                                                              Distem::Resource::VIface::VTraffic::Direction::OUTPUT,{"bandwidth" =>{"rate" => "#{n}00mbps"}})
      vnode.add_viface(viface)
    end
    @vplatform.add_vnode(vnode)
    expect{@vplatform.vnodes_to_dot(@dot_file)}.not_to raise_error
  end

  it "creates dot file 2 vnodes with multiple network interfaces network interfaces and one interface without bandwidth" do
    vnode = Distem::Resource::VNode.new("node6","")
    vnode.add_vcpu(1,1,0)
    (1..2).each do |n|
      viface = Distem::Resource::VIface.new("if#{n}",vnode,{})
      viface.voutput = Distem::Resource::VIface::VTraffic.new(viface,
                                                              Distem::Resource::VIface::VTraffic::Direction::OUTPUT,{"bandwidth" =>{"rate" => "#{n}00mbps"}})
      vnode.add_viface(viface)
    end
    #Adding interface without bandwidth definition
    viface = Distem::Resource::VIface.new("if-adm",vnode,{})
    vnode.add_viface(viface)
    @vplatform.add_vnode(vnode)
    expect{@vplatform.vnodes_to_dot(@dot_file)}.not_to raise_error
  end


  it "loads a physical topology"  do
    expect(@vplatform.load_physical_topo("spec/input/physical-net.dot")).to be_an_instance_of(Hash)
  end

  it "raises an error to a problem with the syntax on the DOT file"  do
    expect{@vplatform.load_physical_topo("spec/input/complex-physical-topo.dot")}.to raise_error(Distem::Lib::ParameterError)
  end


end
