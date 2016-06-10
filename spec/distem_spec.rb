require 'spec_helper'

describe Distem do

  subject { Distem::NetAPI::Client.new(ENV['DISTEM_COORDINATOR']) }

  before :all do

    cmd_distem_bootstrap = `scripts/distem-bootstrap -f #{ENV['MACHINEFILE']}`
    puts cmd_distem_bootstrap
  end

  it "checks distem is running" do
    expect{ subject.pnodes_info() }.not_to raise_error
  end

  it "checks the number of pnodes running" do
    expect(subject.pnodes_info().keys.length).to be > 1
  end

  it "checks vnodes running" do
    expect(subject.vnodes_info().keys.length).to be 0
  end

end
