module TCWrapper # :nodoc: all

require 'wrekavoc'


class QdiscTBF < Qdisc
  TYPE="tbf"

  def initialize(iface,parent,params=Hash.new)
    super(iface,parent,TYPE,params)
  end
end

end
