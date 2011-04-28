module NetAPI

require 'sinatra/base'
require 'netapi'
require 'client'
require 'ressource'
require 'admin'
require 'pnode'

class Server < Sinatra::Base
  set :environment, :developpement
  set :run, true

  def initialize()
    super()
    @daemon_admin = Daemon::Admin.new
    @daemon_ressources = Daemon::Ressource.new
  end

  def daemon?
    @target != TARGET_SELF
  end

  before do
    @target = params['target']
    @ret = (daemon? ? "(#{@target}) " : "")
  end

  after do
    @target = nil
    @ret = nil
  end

  post VNODE_CREATE do
    # >>> TODO: Validate target addr ?

    if daemon?
      pnode = @daemon_ressources.get_pnode(@target)
      vnode = VNode.new(pnode,params['name'])
      @daemon_ressources.add_vnode(vnode)

      @daemon_admin.pnode_run_server(pnode)
      
      cl = Client.new(@target)
      @ret += cl.vnode_create(TARGET_SELF,vnode.name)
    else
      @ret += "Virtual node '#{params['name']}' created"
    end

    return @ret
  end

  Server.run!
end

end
