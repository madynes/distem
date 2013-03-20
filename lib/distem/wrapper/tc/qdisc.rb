module TCWrapper # :nodoc: all



  class Qdisc < Wrapper
    WTYPE="qdisc"

    attr_reader :id, :parentid
    def initialize(iface,parent,type,params)
      super(iface,WTYPE,type,params)
      @parent = parent
      #Here @id corresponds to the handle of the current qdisc
      if (@parent.kind_of? QdiscRoot)
        @id = Id.new(@parent.id.major,0)
      else
        @id = Id.new(Id.get_unique_major_id(iface),0)
      end

      if (@parent.kind_of? Class)
        @parentid = @parent.id
      else
        @parentid = Id.new(@parent.id.major,@parent.id.next_minor_id)
      end
    end

    def get_cmd(*args)
      super(*args) \
        + ((@parent.kind_of? QdiscRoot) ? \
           "root" : "parent " + @parentid.to_s) \
           + " handle " + @id.to_s + " " + @type + " " + get_params
    end
  end

end
