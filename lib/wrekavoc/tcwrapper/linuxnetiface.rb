module TCWrapper

require 'wrekavoc'

class LinuxNetworkInterface
  def initialize(name)
    @name = name
  end

  def to_s
    @name
  end
end

end
