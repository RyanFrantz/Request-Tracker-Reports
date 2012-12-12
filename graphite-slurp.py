#!/usr/bin/python

# graphite-slurp.py - slurp in a metric we've been served and feed it to Graphite

# TODO
# add support for receiving multiple metrics at once (we only take one per script call right now)

import sys
import time
from socket import socket

CARBON_SERVER = 'xxx.xxx.xxx.xxx'
CARBON_PORT = 2003

metric = sys.argv[1]
# should be something like:
#	"foo.bar.count 10 1352314090"

metric = metric.strip('"')	# just in case...
metric = metric + '\n'	# Graphite requires the final newline
request = metric

sock = socket()
try:
	sock.connect( (CARBON_SERVER,CARBON_PORT) )
except:
	print "Couldn't connect to %(server)s on port %(port)d, is carbon-agent.py running?" % { 'server':CARBON_SERVER, 'port':CARBON_PORT }
	sys.exit(1)

#print "\n[" + sys.argv[0] + "] sending request\n"
#print '-' * 80
#print request
#print
sock.sendall(request)
