module TCWrapper # :nodoc: all

  require 'distem'


  class QdiscPrio < Qdisc
    TYPE = "prio"

    def initialize(iface,parent,params=Hash.new)
      super(iface,parent,TYPE,params)
    end
  end

end
