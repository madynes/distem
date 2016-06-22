require 'spec_helper'

describe Distem do

  before :all do

    # Distem installation
    content = File.readlines('machinefile')
    @daemon = Distem::Daemon::DistemCoordinator.new()
    @hosts = content.map{ |h| h.chop}
    @image_path = "file:///vagrant/tmp/ubuntu-wily-lxc.tar.gz"
    @pnodes = []
  end

  it "initialize a pnode" do
    @pnodes.push(@daemon.pnode_create(@hosts.first).first)
    expect(@pnodes).to be_an_instance_of(Array)
  end

  it "checks that we have created a pnode" do
    expect(@pnodes.first).to be_an_instance_of(Distem::Resource::PNode)
  end

  it "checks the ip adress" do
    pnode = @pnodes.first
    expect(pnode.address.to_s).to eq(@hosts.first)
  end

  it "checks status" do
    pnode = @pnodes.first
    expect(pnode.status).to be_an_instance_of(String)
    expect(pnode.status).to eq("RUNNING")
  end

  it "raises already existing exception" do
    expect{@daemon.pnode_create(@hosts.first)}.to raise_error(Distem::Lib::AlreadyExistingResourceError)
  end

  it "gets a pnode" do
    expect(@daemon.pnode_get(@hosts.first)).to be_an_instance_of(Distem::Resource::PNode)
  end

  it "gets an invalid parameter exception" do
    expect{@daemon.pnode_create(random_string)}.to raise_error(Distem::Lib::InvalidParameterError)
  end

  it "gets an unreachable resource exception" do
    expect{@daemon.pnode_create('255.255.255.255')}.to raise_error(Distem::Lib::UnreachableResourceError)
  end

  it "gets an resource not found exception" do
    expect{@daemon.pnode_get('255.255.255.255')}.to raise_error(Distem::Lib::ResourceNotFoundError)
  end


  # it "checks the number of pnodes running" do
  #   expect(subject.pnodes_info().keys.length).to be > 0
  # end

  # it "checks that no vnode exists" do
  #   expect(subject.vnodes_info().keys.length).to be 0
  # end

  # it "checks that no vnetwork has been created" do
  #   expect(subject.vnetworks_info.empty?).to be true
  # end

  # it "creates a vnetwork" do
  #   expect{ subject.vnetwork_create("test","10.144.0.0/22")}.not_to raise_error
  # end

  # it "checks if a vnetwork exists" do
  #   expect(subject.vnetworks_info.empty?).to be false
  # end

  # it "creates a fake vnode" do
  #   expect{subject.vnode_create("test1",{},{})}.not_to raise_error
  # end

  # it "checks that a vnode has been created" do
  #   expect(subject.vnodes_info().keys.length).to be > 0
  # end

  # it "creates a real vnode" do
  #   desc = {'vfilesystem' =>{'image' => @image_path,'shared' => true},
  #           'vifaces' => [{'name' => 'if0', 'vnetwork' => "test" }]}

  #   expect{subject.vnode_create("node1",desc,{})}.not_to raise_error
  # end

  # it "start a vnode" do
  #   expect{subject.vnode_start("node1")}.not_to raise_error
  # end

  # it "gets info from the vnode" do
  #   expect(subject.vnodes_info()).to be_an_instance_of(Hash)
  # end

  after :all do
    @daemon.pnodes_quit
  end
end
