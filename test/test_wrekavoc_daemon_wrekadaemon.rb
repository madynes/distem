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
    invalidaddr = random_string
    unreachableaddr = '255.255.255.255'

    @daemon_d.pnode_init(localaddr)
    pnode = @daemon_d.daemon_resources.get_pnode_by_address(localaddr)
    assert_not_nil(pnode)
    assert_equal(localaddr,pnode.address.to_s)
    assert_equal(pnode.status,Wrekavoc::Resource::PNode::STATUS_RUN)

    assert_raise(Wrekavoc::Lib::InvalidParameterError) {
      @daemon_d.pnode_init(invalidaddr)
    }

    assert_raise(Wrekavoc::Lib::UnreachableResourceError) {
      @daemon_d.pnode_init(unreachableaddr)
    }
  end
end
