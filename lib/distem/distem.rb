# All the distem related classes
module Distem
  def self.client(serveraddr="localhost",port=4567)
    yield(NetAPI::Client.new(serveraddr,port,64))
  end

  def self.encode16(string)
    string.unpack('U'*string.length).collect {|x| x.to_s 16}.join
  end

  def self.decode16(hex)
    hex.unpack('a2'*(hex.size/2)).collect {|i| i.hex.chr }.join
  end

end
