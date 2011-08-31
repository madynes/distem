module TCWrapper # :nodoc: all

require 'distem'


class QdiscTBF < Qdisc
  TYPE="tbf"

  def initialize(iface,parent,params=Hash.new)
    super(iface,parent,TYPE,params)
  end
end

end
