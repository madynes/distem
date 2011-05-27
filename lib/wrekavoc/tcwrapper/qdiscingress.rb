module TCWrapper

require 'wrekavoc'


class QdiscIngress < Qdisc
  TYPE="ingress"

  def initialize(iface,parent,params=Hash.new)
    super(iface,parent,TYPE,params)
  end
end

end

