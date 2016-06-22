require 'spec_helper'

describe Distem::Lib::FileManager do

  before :all do

    # Distem installation
   vnode = Distem::Resource::VNode.new("node1","")
   @fs = Distem::Resource::FileSystem.new(vnode,Tempfile.new("image").path)
  end

  it "creates a filesystem object" do
    expect(Distem::Resource::FileSystem.new("node1","/tmp/testimage")).to be_an_instance_of(Distem::Resource::FileSystem)
  end

  it "gets a file" do
    tempfile = Tempfile.new("test")
    expect{Distem::Lib::FileManager.download(URI.parse("file://#{tempfile.path}"))}.not_to raise_error
  end

 it "gets a file using filesystem object" do
   #fs = Distem::Resource::FileSystem.new("node1",Tempfile.new("image").path)
   expect{Distem::Lib::FileManager.download(@fs.image)}.not_to raise_error
 end

 it "to string" do
   expect(@fs.to_s).to be_an_instance_of(String)
 end


 # it "gets a file using filesytem

end
