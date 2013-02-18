module TCWrapper # :nodoc: all



  class QdiscIngress < Wrapper
    TYPE="qdisc"

    attr_reader :id

    def initialize(iface)
      super(iface,TYPE,"ingress",Hash.new)
      @id = Id.new("ffff")
    end

    def get_cmd(*args)
      super(*args) + "ingress"
    end
  end

end

