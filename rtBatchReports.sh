#!/bin/bash

#
# rtBatchReports.sh - generate and send custom RT reports
#

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
dateTime="`date +%x' '%T`"

# wipe it down
/bin/rm -f /tmp/rtBatchReports.tmp

# batch it up
echo "== [Ticket Lifetime] ==" >> /tmp/rtBatchReports.tmp
/usr/local/bin/rtTicketLifetime.pl >> /tmp/rtBatchReports.tmp

echo "== [Ticket Lifetime by Owner] ==" >> /tmp/rtBatchReports.tmp
/usr/local/bin/rtTicketLifetimeByOwner.pl >> /tmp/rtBatchReports.tmp

echo "== [Ticket Response] ==" >> /tmp/rtBatchReports.tmp
/usr/local/bin/rtTicketFirstResponse.pl >> /tmp/rtBatchReports.tmp

echo "== [Ticket Time Worked] ==" >> /tmp/rtBatchReports.tmp
/usr/local/bin/rtTicketTimeWorked.pl >> /tmp/rtBatchReports.tmp

# send it out
/bin/mail -s "RT: Batch Reports [$dateTime]" foo@example.com, bar@example.com < /tmp/rtBatchReports.tmp
