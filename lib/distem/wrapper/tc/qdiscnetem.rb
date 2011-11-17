module TCWrapper # :nodoc: all

  require 'distem'


  class QdiscNetem < Qdisc
    TYPE="netem"

    def initialize(iface,parent,params=Hash.new)
      super(iface,parent,TYPE,params)
    end
  end

end
