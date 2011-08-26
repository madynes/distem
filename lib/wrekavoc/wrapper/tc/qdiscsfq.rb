module TCWrapper # :nodoc: all

require 'wrekavoc'


class QdiscSFQ < Qdisc
  TYPE="sfq"

  def initialize(iface,parent,params=Hash.new)
    super(iface,parent,TYPE,params)
  end
end

end
