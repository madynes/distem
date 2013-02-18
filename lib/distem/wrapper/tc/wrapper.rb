
module TCWrapper # :nodoc: all

  class Wrapper
    CMDBIN="tc"

    def initialize(iface,wtype,type,params)
      @iface = iface
      @wtype = wtype
      @type = type

      unless (params.kind_of? Hash)
        raise "Params must be a Hash"
      end

      @params = params
    end

    #Argument 1: the action
    def get_cmd(*args)
      CMDBIN + " " + @wtype + " " + args[0] + " dev " + @iface + " "
    end

    def get_params
      ret = ""
      @params.each{ |name,val| ret += name + " " + val.to_s + " "}
      return ret
    end

    def add_param(name,val)
      @params[name] = val
    end
  end

end
