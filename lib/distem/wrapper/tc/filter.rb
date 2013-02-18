
module TCWrapper # :nodoc: all

  class Filter < Wrapper
    WTYPE="filter"

    attr_reader :id, :parentid

    def initialize(iface,parent,dest,protocol,prio,type,params)
      super(iface,WTYPE,type,params)
      @parent = parent
      @dest = dest
      @protocol = protocol
      @prio = prio
      @filterparams = {}

      @id = Id.new(@parent.id.major,@parent.id.next_minor_id)
      @parentid = @parent.id
      if (@dest.kind_of? Qdisc)
        @destid = @dest.parentid
      else
        @destid = @dest.id
      end
    end

    def get_cmd(*args)
      super(*args) \
        + ((@parent.kind_of? QdiscRoot) ? \
           "root" : "parent " + @parentid.to_s) \
           + " protocol " + @protocol + (@prio > 0 ? " prio " + @prio.to_s : "") \
           + " " + @type + " " + get_filter_params + " flowid " + @destid.to_s \
           + " " + get_params
    end

    def get_filter_params
      ret = ""
      @filterparams.each{ |name,val| ret += name + " " + val.to_s + " "}
      return ret
    end

    def add_filter_param(name,val)
      @filterparams[name] = val
    end
  end

end
