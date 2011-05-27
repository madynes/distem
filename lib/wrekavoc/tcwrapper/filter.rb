module TCWrapper

require 'wrekavoc'


class Filter < Wrapper
  WTYPE="filter"

  attr_reader :id, :parentid

  def initialize(iface,parent,dest,protocol,prio,type,params)
    super(iface,WTYPE,type,params)
    @parent = parent
    @dest = dest
    @protocol = protocol
    @prio = prio

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
      + " protocol " + @protocol + " prio " + @prio.to_s + " " + @type + " " \
      + get_params + " flowid " + @destid.to_s
  end
end

end
