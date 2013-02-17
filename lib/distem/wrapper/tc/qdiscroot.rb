module TCWrapper # :nodoc: all



  class QdiscRoot < Wrapper
    TYPE="qdisc"

    attr_reader :id

    def initialize(iface)
      super(iface,TYPE,"root",Hash.new)
      @id = IdRoot.new
    end

    def get_cmd(*args)
      super(*args) + "root"
    end
  end

end
