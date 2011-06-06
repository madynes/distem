#!/bin/bash

IMAGE='file:///home/lsarzyniec/rootfs.tar.bz2'
WREKAVOC='bin/wrekavoc'
WREKANET='bin/wrekanet'

MACHINE1='graphene-93'
MACHINE2='graphene-94'
MACHINE3='graphene-95'
COORD=$MACHINE1

NET1='network1'
NET2='network2'

#Physical node init
$WREKAVOC $COORD -i $MACHINE1 
$WREKAVOC $COORD -i $MACHINE2
$WREKAVOC $COORD -i $MACHINE3 

#VNetworks creation
$WREKANET $COORD -c ${NET1},'10.144.2.1/24'
$WREKANET $COORD -c ${NET2},'10.144.3.1/24'

#VNodes creation
$WREKAVOC $COORD -H $MACHINE1 -c 'node1',$IMAGE -f 'if0' -N $NET1 -A
$WREKAVOC $COORD -H $MACHINE1 -c 'node2',$IMAGE -f 'if0' -N $NET2 -A
$WREKAVOC $COORD -H $MACHINE2 -c 'node3',$IMAGE -f 'if0' -N $NET2 -A
$WREKAVOC $COORD -H $MACHINE3 -c 'node4',$IMAGE -f 'if0' -N $NET2 -A
$WREKAVOC $COORD -H $MACHINE3 -c 'nodegw',$IMAGE
$WREKAVOC $COORD -n 'nodegw' -f 'if0' -N $NET1 -A
$WREKAVOC $COORD -n 'nodegw' -f 'if1' -N $NET2 -A

#VRoutes creation
$WREKANET $COORD -X

#Starting VNodes
$WREKAVOC $COORD -n 'node1' -s
$WREKAVOC $COORD -n 'node2' -s
$WREKAVOC $COORD -n 'node3' -s
$WREKAVOC $COORD -n 'nodegw' -s

#Limitations
$WREKANET $COORD -n 'nodegw' -I 'if0' -o -L '{ "bandwidth" : {"rate" : "20mbps"}, "latency" : {"delay" : "5ms"} }' 
$WREKANET $COORD -n 'nodegw' -I 'if0' -i -L '{ "bandwidth" : {"rate" : "10mbps"}, "latency" : {"delay" : "15ms"} }'
$WREKANET $COORD -n 'nodegw' -I 'if1' -o -L '{ "bandwidth" : {"rate" : "2mbps"}, "latency" : {"delay" : "50ms"} }'
$WREKANET $COORD -n 'nodegw' -I 'if1' -i -L '{ "bandwidth" : {"rate" : "4mbps"}, "latency" : {"delay" : "25ms"} }'
