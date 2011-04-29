module Wrekavoc

  class VIface
    attr_reader :name

    def initialize(name, ip)
      raise if name.empty? or not name.is_a?(String)
      raise if ip.empty? or not ip.is_a?(String)

      @name = name
      # >>> TODO: use IPAddress to validate/store the ip
      @ip = ip
    end
  end

end
