module Wrekavoc
  module NetAPI

    TARGET_SELF=''

    PNODE_INIT='/pnodes'

    VNODE_CREATE='/vnodes'
    VNODE_START='/vnodes/start'
    VNODE_STOP='/vnodes/stop'
    VNODE_EXECUTE='/vnodes/execute' # Daemon only
    VNODE_GATEWAY='/vnodes/gateway'
    VIFACE_CREATE='/vnodes/vifaces'
    VIFACE_ATTACH='/vnodes/vifaces/attach' # Node only
    VNODE_INFO_ROOTFS='/vnodes/infos/rootfs'
    VNODE_INFO_PNODE='/vnodes/infos/pnode'
    VNODE_INFO_LIST='/vnodes'
    
    VNETWORK_CREATE='/vnetworks' # Daemon only
    VNETWORK_ADD_VNODE='/vnetworks/vnodes/add' # Daemon only
    VROUTE_CREATE='/vnetworks/vroutes'
    VROUTE_COMPLETE='/vnetworks/vroutes/complete' # Daemon only
    VNETWORK_INFO_LIST='/vnetworks/info/list'

    LIMIT_NET_CREATE='/limitations/network'
  end
end
