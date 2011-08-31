module TCWrapper # :nodoc: all

require 'wrekavoc'

class Id
  attr_reader :major, :minor
  @@majors = 0

  def initialize(major,minor=0)
    @major = major
    @minor = minor

    @minors = minor
  end

  def next_minor_id
    @minors += 1
  end

  def self.get_unique_major_id
    @@majors += 1
    @@majors * 10
  end

  def to_s
    @major.to_s + ":" + (@minor > 0 ? @minor.to_s : "")
  end
end

end
