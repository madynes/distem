module TCWrapper # :nodoc: all


  class Netem

    attr_accessor :latency
    attr_accessor :loss
    attr_accessor :corruption
    attr_accessor :duplication
    attr_accessor :reordering
    attr_accessor :bandwidth

    def initialize(action, iface)
      @action = action
      @iface = iface
      @latency = nil
      @loss = nil
      @corruption = nil
      @duplication = nil
      @reordering = nil
      @bandwidth = nil
    end


    def get_cmd()

      cmd = "tc qdisc #{@action} dev #{@iface} root netem"

      if @latency && @latency[:delay]
        cmd +=  " delay #{@latency[:delay]} #{@latency[:jitter]}"
      end
      if @loss && @loss[:percent]
        cmd += " loss #{@loss[:percent]}"
      end
      if @corruption && @corruption[:percent]
        cmd += " corrupt #{@corruption[:percent]}"
      end
      if @duplication && @duplication[:percent]
        cmd += " duplicate #{@duplication[:percent]}"
      end
      if @reoredering && @reordering[:percent]
        cmd += " reorder #{@reordering[:percent]}"
      end
      if @bandwidth && @bandwidth[:rate]
        cmd += " rate #{@bandwidth[:rate]}"
      end
      return cmd
    end

  end

end
