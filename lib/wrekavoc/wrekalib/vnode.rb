require 'pnode'
require 'viface'
require 'resolv'

class VNode
  @@ids = 0
  attr_reader :id, :name, :host

  def initialize(host, name="")
    raise unless name.is_a?(String)
    raise unless host.is_a?(PNode)

    @id = @@ids

    if name.empty?
      @name = "vnode" + @id.to_s
    else
      @name = name
    end

    @host = host
    @vifaces = []
    @@ids += 1
  end

  def add_viface(viface)
    raise unless viface.is_a?(VIface)
    @vifaces << viface
  end
end
