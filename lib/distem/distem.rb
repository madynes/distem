# All the distem related classes
module Distem
  def self.client(serveraddr="localhost",port=4567)
    yield(NetAPI::Client.new(serveraddr,port,64))
  end
end
