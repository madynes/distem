module TCWrapper

require 'wrekavoc'

class CommandList < Array
  def add(action,wrapper)
    self << wrapper.get_cmd(action)
  end

  def print
    each{ |line| puts line + "\n"} 
  end
end

end
