module TCWrapper # :nodoc: all


  class Id
    attr_reader :major, :minor
    @@majors = {}

    def initialize(major,minor=0)
      @major = major
      @minor = minor

      @minors = minor
    end

    def next_minor_id
      @minors += 1
    end

    def self.get_unique_major_id(iface)
      @@majors[iface] = 0 unless @@majors[iface]
      @@majors[iface] += 1
      @@majors[iface] * 10
    end

    def to_s
      @major.to_s + ":" + (@minor > 0 ? "0x#{@minor.to_s(16)}" : "")
    end
  end

end
