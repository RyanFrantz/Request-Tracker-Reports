#!/usr/bin/perl

#
# rtTicketLoad.pl - query RT and generate a report on the load the Support Desk experiences (measured using various units)
#

use strict;
use warnings;

use lib "/usr/local/rt/lib";

use RT;
use RT::User;
use RT::Interface::CLI qw( CleanEnv GetCurrentUser );	# I guess these aren't exported?

use DateTime;

## start me up!

# set the stage...
CleanEnv();
RT::LoadConfig;
RT::Init;

sub getTicketLoad {
	my ( $startYMD, $endYMD ) = @_;

	my $currentUser = GetCurrentUser();
	my $tickets = RT::Tickets->new( $currentUser );

	my $query = qq[ Created > "$startYMD" AND Created < "$endYMD" AND ( Queue = 'Support Desk (Level 1)' OR Queue = 'Support Desk (Level 2)' OR Queue = 'Product Management' ) ];

	my $validQuery = $tickets->FromSQL( $query );

	my %statuses;
	my %queues;
	while ( my $ticket = $tickets->Next() ) {

		$statuses{ $ticket->Status }++;
		my $queue = $ticket->QueueObj;
		$queues{ $queue->Name }++;

	}

	print "== [Ticket Load] ==\n";
	print "\n" . localtime() . "\n";
	print "\nQuery: $query\n";
	print "\nFound " . $tickets->CountAll . " tickets\n\n";

	print "[Ticket Count By Status]\n";
	foreach my $status ( sort keys %statuses ) {
		print $status . ": " . $statuses{ $status } . "\n";
		my $graphiteSlurpMetric = "support_desk.load.tickets.$status $statuses{ $status } " . time();
		#print $graphiteSlurpMetric . "\n";	# debug
		system("/usr/local/bin/graphite-slurp.py", $graphiteSlurpMetric);
	}
	print "\n";
	print "[Ticket Count By Queue]\n";
	foreach my $queue ( sort keys %queues ) {
		print $queue . ": " . $queues{ $queue } . "\n";
		# we may have spaces and parentheses in our queue names; homogenize them to underscores
		my $cleansedQueueName = $queue;
		$cleansedQueueName =~ s/\(/ /g;
		$cleansedQueueName =~ s/\)//g;
		$cleansedQueueName =~ s/\s+/ /g;
		$cleansedQueueName =~ s/ /_/g;
		my $graphiteSlurpMetric = "support_desk.load.queue.$cleansedQueueName $queues{ $queue } " . time();
		#print $graphiteSlurpMetric . "\n";	# debug
		system("/usr/local/bin/graphite-slurp.py", $graphiteSlurpMetric);
	}
	print "\n";
}

my $startDate = DateTime->now();
my $endDate = DateTime->now();
$startDate->subtract( days => '7' );
my $startYMD = $startDate->ymd();
my $endYMD = $endDate->ymd();
#print "START DATE: " . $startDate->ymd() . "\n";	# debug
#print "END DATE: " . $endDate->ymd() . "\n";		# debug

getTicketLoad( $startYMD, $endYMD );
