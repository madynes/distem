
module TCWrapper # :nodoc: all

  class Class < Wrapper
    WTYPE="class"

    attr_reader :id, :parentid

    def initialize(iface,parent,type,params)
      super(iface,WTYPE,type,params)
      @parent = parent
      @id = Id.new(@parent.id.major,@parent.id.next_minor_id)
      @parentid = @parent.id
    end

    def get_cmd(*args)
      if (@parent.kind_of? QdiscRoot)
        raise "Can't link a class to root directly"
      end

      super(*args) + "parent " + @parentid.to_s + " classid " + @id.to_s + " " \
        + @type + " " + get_params
    end
  end

end
