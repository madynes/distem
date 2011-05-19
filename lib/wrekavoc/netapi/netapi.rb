module Wrekavoc
  module NetAPI

    TARGET_SELF=''

    PNODE_INIT='/pnodes/init'

    VNODE_CREATE='/vnodes/create'
    VNODE_START='/vnodes/start'
    VNODE_STOP='/vnodes/stop'
    VNODE_EXECUTE='/vnodes/execute' # Daemon only
    VNODE_GATEWAY='/vnodes/gateway'
    VIFACE_CREATE='/vnodes/vifaces/create'
    VIFACE_ATTACH='/vnodes/vifaces/attach' # Node only
    VNODE_INFO_ROOTFS='/vnodes/info/rootfs'
    VNODE_INFO_LIST='/vnodes/info/list'
    
    VNETWORK_CREATE='/vnetworks/create' # Daemon only
    VNETWORK_ADD_VNODE='/vnetworks/vnodes/add' # Daemon only
    VROUTE_CREATE='/vnetwork/vroute/create'
    VNETWORK_INFO_LIST='/vnetwork/info/list'

  end
end
