#!/bin/bash

RCBIN='restclient'
IMAGE='file:///home/lsarzyniec/rootfs.tar.bz2'

MACHINE1='graphene-93'
MACHINE2='graphene-94'
MACHINE3='graphene-95'
COORD=$MACHINE1

NET1='network1'
NET2='network2'

function restpost {
  echo "post '${1}',${2}" | $RCBIN "http://${COORD}:4567"
}

#Physical node init
restpost "/pnodes/init" "{'target' => '${MACHINE1}'}"
restpost "/pnodes/init" "{'target' => '${MACHINE2}'}"
restpost "/pnodes/init" "{'target' => '${MACHINE3}'}"


#VNetworks creation
restpost "/vnetworks/create" "{'name' => '${NET1}', 'address' => '10.144.2.1/24'}"
restpost "/vnetworks/create" "{'name' => '${NET2}', 'address' => '10.144.3.1/24'}"

#Node 1 creation
node='node1'
restpost "/vnodes/create" "{'target' => '${MACHINE1}', 'name' => '${node}', 'image' => '${IMAGE}'}"
restpost "/vnodes/vifaces/create" "{'vnode' => '${node}', 'name' => 'if0'}"
restpost "/vnetworks/vnodes/add" "{'vnetwork' => '${NET1}', 'vnode' => '${node}', 'viface' => 'if0'}"

#Node 2 creation
node='node2'
restpost "/vnodes/create" "{'target' => '${MACHINE1}', 'name' => '${node}', 'image' => '${IMAGE}'}"
restpost "/vnodes/vifaces/create" "{'vnode' => '${node}', 'name' => 'if0'}"
restpost "/vnetworks/vnodes/add" "{'vnetwork' => '${NET2}', 'vnode' => '${node}', 'viface' => 'if0'}"

#Node 3 creation
node='node3'
restpost "/vnodes/create" "{'target' => '${MACHINE2}', 'name' => '${node}', 'image' => '${IMAGE}'}"
restpost "/vnodes/vifaces/create" "{'vnode' => '${node}', 'name' => 'if0'}"
restpost "/vnetworks/vnodes/add" "{'vnetwork' => '${NET2}', 'vnode' => '${node}', 'viface' => 'if0'}"

#Node 4 creation
node='node4'
restpost "/vnodes/create" "{'target' => '${MACHINE3}', 'name' => '${node}', 'image' => '${IMAGE}'}"
restpost "/vnodes/vifaces/create" "{'vnode' => '${node}', 'name' => 'if0'}"
restpost "/vnetworks/vnodes/add" "{'vnetwork' => '${NET2}', 'vnode' => '${node}', 'viface' => 'if0'}"

#Node GW creation

node='nodegw'
restpost "/vnodes/create" "{'target' => '${MACHINE3}', 'name' => '${node}', 'image' => '${IMAGE}'}"
restpost "/vnodes/vifaces/create" "{'vnode' => '${node}', 'name' => 'if0'}"
restpost "/vnetworks/vnodes/add" "{'vnetwork' => '${NET1}', 'vnode' => '${node}', 'viface' => 'if0'}"
restpost "/vnodes/vifaces/create" "{'vnode' => '${node}', 'name' => 'if1'}"
restpost "/vnetworks/vnodes/add" "{'vnetwork' => '${NET2}', 'vnode' => '${node}', 'viface' => 'if1'}"

#VRoutes creation
restpost "/vnetworks/vroutes/complete" "{}"

#Starting VNodes
restpost "/vnodes/start" "{'vnode' => 'node1'}"
restpost "/vnodes/start" "{'vnode' => 'node2'}"
restpost "/vnodes/start" "{'vnode' => 'node3'}"
restpost "/vnodes/start" "{'vnode' => 'nodegw'}"

#Limitations
json='{ "bandwidth" : {"rate" : "20mbps"}, "latency" : {"delay" : "5ms"} }'
restpost "/limitations/network/create" "{'vnode' => 'nodegw', 'viface' => 'if0', 'direction' => 'OUTPUT', 'properties' => '${json}'}"
json='{ "bandwidth" : {"rate" : "10mbps"}, "latency" : {"delay" : "15ms"} }'
restpost "/limitations/network/create" "{'vnode' => 'nodegw', 'viface' => 'if0', 'direction' => 'INPUT', 'properties' => '${json}'}"
json='{ "bandwidth" : {"rate" : "2mbps"}, "latency" : {"delay" : "50ms"} }'
restpost "/limitations/network/create" "{'vnode' => 'nodegw', 'viface' => 'if1', 'direction' => 'OUTPUT', 'properties' => '${json}'}"
json='{ "bandwidth" : {"rate" : "4mbps"}, "latency" : {"delay" : "25ms"} }'
restpost "/limitations/network/create" "{'vnode' => 'nodegw', 'viface' => 'if1', 'direction' => 'INPUT', 'properties' => '${json}'}"
