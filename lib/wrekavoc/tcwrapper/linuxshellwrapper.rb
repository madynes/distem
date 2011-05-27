module TCWrapper

require 'wrekavoc'

module LinuxShellWrapper
  def get_cmd(*args)
    raise NotImplementedError.new
  end

  def apply_cmd
   raise NotImplementedError.new
  end
end

end
