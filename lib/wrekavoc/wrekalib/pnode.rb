require 'resolv'

module Wrekavoc

  class PNode
    STATUS_INIT=0
    STATUS_RUN=1

    @@ids = 0
    attr_reader :id, :address, :ssh_user, :ssh_password, :status
    attr_writer :status

    def initialize(hostname, ssh_user="root", ssh_password="")
      @id = @@ids
      @address = Resolv.getaddress(hostname)
      @ssh_user = ssh_user
      @ssh_password = ssh_password
      @status = STATUS_INIT

      @@ids += 1
    end

    def ==(pnode)
      @address == pnode.address
    end
  end

end
