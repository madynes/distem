module Wrekavoc
  module NetAPI

    TARGET_SELF=''

    PNODE_INIT='/pnodes/init'

    VNODE_CREATE='/vnodes/create'
    VNODE_START='/vnodes/start'
    VNODE_STOP='/vnodes/stop'
    VIFACE_CREATE='/vnodes/vifaces/create'
    VIFACE_ATTACH='/vnodes/vifaces/attach' # Node only
    VNODE_INFO_ROOTFS='/vnodes/info/rootfs'
    
    VNETWORK_CREATE='/vnetworks/create' # Daemon only
    VNETWORK_ADD_VNODE='/vnetworks/vnodes/add' # Daemon only
    VNETWORK_INFO_LIST='/vnetwork/info/list'

  end
end
