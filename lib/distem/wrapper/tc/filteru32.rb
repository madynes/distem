module TCWrapper # :nodoc: all


  class FilterU32 < Filter
    TYPE="u32"

    U32_MATCH="match"

    U32T_U8="u8"
    U32T_U32="u32"
    U32T_IP="ip"

    U32M_IP_DST="ip dst"
    U32M_IP_SRC="ip src"
    U32M_U32="u32"

    def initialize(iface,parent,dest,protocol=Protocol::IP,prio=0,params=Hash.new)
      super(iface,parent,dest,protocol,prio,TYPE,params)
      parse_params
    end

    #params such as: 
    # {
    #   FilterU32::U32T_IP => ["ip protocol 6 0xff", "ip sport 80 0xffff"],
    #   FilterU32::U32T_U32 => ["0x48545450 0xffffffff at 52"]
    # }
    def parse_params
      oldparams = @params.dup
      @params.clear

      oldparams.each do |name,values|
        values.each do |value|
          add_param(name,value)
        end
      end
    end

    def add_match_u32(value,mask)
      add_filter_param(U32_MATCH,U32M_U32 + " " + value + " " + mask)
      return self
    end

    def add_match_ip_dst(ip)
      add_filter_param(U32_MATCH,U32M_IP_DST + " " + ip)
      return self
    end

    def add_match_ip_src(ip)
      add_filter_param(U32_MATCH,U32M_IP_SRC + " " + ip)
      return self
    end
  end

end
