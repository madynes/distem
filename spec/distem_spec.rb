require 'spec_helper'

describe Distem do

  subject { Distem::NetAPI::Client.new(ENV['DISTEM_COORDINATOR']) }

  before :all do

    # Distem installation
    if ENV['COMPILE_PACKAGE']
      puts `scripts/distem-bootstrap -f #{ENV['MACHINEFILE']} -g --ci #{ENV['PWD']}`
      # for G5K when distem has not been installed before
    end
      puts `scripts/distem-devbootstrap -u distemfiles.yml -f #{ENV['MACHINEFILE']}`
      puts `scripts/distem-bootstrap -f #{ENV['MACHINEFILE']}`
      @image_path = "file:///vagrant/tmp/ubuntu-wily-lxc.tar.gz"
  end

  it "checks distem is running" do
    expect{ subject.pnodes_info() }.not_to raise_error
  end

  it "checks the number of pnodes running" do
    expect(subject.pnodes_info().keys.length).to be > 0
  end

  it "checks that no vnode exists" do
    expect(subject.vnodes_info().keys.length).to be 0
  end

  it "checks that no vnetwork has been created" do
    expect(subject.vnetworks_info.empty?).to be true
  end

  it "creates a vnetwork" do
    expect{ subject.vnetwork_create("test","10.144.0.0/22")}.not_to raise_error
  end

  it "checks if a vnetwork exists" do
    expect(subject.vnetworks_info.empty?).to be false
  end

  it "creates a fake vnode" do
    expect{subject.vnode_create("test1",{},{})}.not_to raise_error
  end

  it "checks that a vnode has been created" do
    expect(subject.vnodes_info().keys.length).to be > 0
  end

  it "creates a real vnode" do
    desc = {'vfilesystem' =>{'image' => @image_path,'shared' => true},
            'vifaces' => [{'name' => 'if0', 'vnetwork' => "test" }]}

    expect{subject.vnode_create("node1",desc,{})}.not_to raise_error
  end

  it "start a vnode" do
    expect{subject.vnode_start("node1")}.not_to raise_error
  end

  it "gets info from the vnode" do
    expect(subject.vnodes_info()).to be_an_instance_of(Hash)
  end

  after :all do
    cl = Distem::NetAPI::Client.new(ENV['DISTEM_COORDINATOR'])
    cl.pnodes_quit()
  end
end
