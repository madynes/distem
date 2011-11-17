module TCWrapper # :nodoc: all

  require 'distem'


  class IdRoot < Id
    def initialize
      super(1,0)
    end

    def get_unique_major_id
      "1"
    end

    def to_s
      "root"
    end
  end

end
