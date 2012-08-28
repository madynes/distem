#!/usr/bin/env python

# this program is used to test latency
# don't test RTT bigger than 3 secs - it will break
# we make sure that nothing breaks if there is a packet missing
# this can rarely happen

import select
import socket
import time
import sys
import struct

def pong():
    # easy, receive and send back
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(('0.0.0.0', 1234))

    while True:
        c, addr = s.recvfrom(1)
        s.sendto(c, (addr[0], 1235))
        if c == 'x':
            break

    print 'Finished'
    return 0

def ping(addr, n):
    # send and wait for it back
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(('0.0.0.0', 1235))
    succ = 0
    errs = 0
    while succ != n and errs < 3: # at most 3 lost packets
        time.sleep(0.02)  # wait a bit
        start = time.time()
        s.sendto('r', (addr, 1234))
        h, _, _ = select.select([s], [], [], 3)  # wait 3 seconds
        end = time.time()
        if h == []: # lost packet
            # print '# lost packet'
            errs += 1
            continue
        s.recv(1) # eat the response
        succ += 1
        print '%.8f' % (end - start)
    for x in xrange(10):
        # send many packets to be (almost) sure the other end is done
        s.sendto('x', (addr, 1234))
    return errs >= 3


if __name__ == '__main__':
    if 'ping' in sys.argv:
        ret = ping(sys.argv[2], int(sys.argv[3]))
    elif 'pong' in sys.argv:
        ret = pong()
    else:
        print 'ping or pong?'
        ret = 1
    sys.exit(ret)




