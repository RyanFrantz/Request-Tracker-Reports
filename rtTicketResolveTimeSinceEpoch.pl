#!/usr/bin/perl

#
# rtTicketResolveTimeSinceEpoch.pl - query RT and generate a report on how long it took to resolve requests since _the epoch_
#

use warnings;
use strict;

use lib "/usr/local/rt/lib/";

use RT;
use RT::User;
use RT::Interface::CLI qw( CleanEnv GetCurrentUser );   # I guess these aren't exported?

use Date::Calc qw( Date_to_Time );
use Time::Interval;

## start me up!

# set the stage...
CleanEnv();
RT::LoadConfig;
RT::Init;

my $epoch = '2011-09-19';
my $currentUser = GetCurrentUser();
my $tickets = RT::Tickets->new( $currentUser );
my $query = qq[ Created >= '2011-09-19' AND ( Queue = 'Support Desk (Level 1)' OR Queue = 'Support Desk (Level 2)' ) AND Status = 'resolved' ];

my $binThreshold = '604800';	# 7 days, in seconds
# define the response times for each bin; in seconds
my %histogramData = (
	'86400'		=>	'0',	# 1day
	'172800'	=>	'0',	# 2days
	'259200'	=>	'0',	# 3days
	'345600'	=>	'0',	# 4days
	'432000'	=>	'0',	# 5days
	'518400'	=>	'0',	# 6days
	$binThreshold	=>	'0',	# 7days
	#'more'	=>	'0'	# $binThreshold + 1; we'll add this key in at the end
);

my $numAboveBinThreshold;
sub tallyResponseTime {

	my $responseTime = shift;
	#print "\nTEST VALUE: $responseTime\n";	# debug
	my $rangeLow = '0';

	foreach my $binResponseTime ( sort { $a <=> $b } keys %histogramData ) {	# ensure a numeric sort; not ASCII-betical
		if ( $responseTime >= $rangeLow and $responseTime < $binResponseTime ) {
			$histogramData{ $binResponseTime }++;
			last;   # no need to continue
		} elsif ( $responseTime > $binThreshold ) {
			$numAboveBinThreshold++;	# we'll add this value to a 'more' key in the hash at the end of the script
			last;
		}

		$rangeLow = $binResponseTime;
	}

}	# end tallyResponseTime()

my $validQuery = $tickets->FromSQL( $query );
#print "VALID QUERY!\n" if $validQuery;	# debug

# compare the ticket Created and Resolved times to determine response time
my $totalTickets = '0';
my $skippedTickets = '0';
while ( my $ticket = $tickets->Next() ) {
	my $dateTicketCreated = $ticket->CreatedObj->Get( Timezone => 'server' );
        my @dateTicketCreated = split( /-|:| /, $dateTicketCreated );
	my $timeTicketCreated = Date_to_Time( @dateTicketCreated );	# seconds since epoch
	my $dateTicketResolved = $ticket->ResolvedObj->Get( Timezone => 'server' );
	if ( $dateTicketResolved =~ /1969-12-31/ ) {
		# we found a resolved ticket with a null 'Closed' date; ignore it, but count it; weird...
		$skippedTickets++;
		next;
	}
        my @dateTicketResolved = split( /-|:| /, $dateTicketResolved );
	my $timeTicketResolved = Date_to_Time( @dateTicketResolved );	# seconds since epoch
	my $timeDiff = $timeTicketResolved - $timeTicketCreated;

	tallyResponseTime( $timeDiff );
	$totalTickets++;
}

# after all tallies, add the key/value pair for those tickets whose response time was above our bin threshold
$histogramData{ $binThreshold + 1 } = $numAboveBinThreshold || '0';	# 7201 seconds; NOTE: there may be none at this level, default to '0'

# report!
print "\n" . localtime() . "\n";
print "\nQUERY: $query\n\n";
foreach my $key ( sort { $a <=> $b } keys %histogramData ) {    # ensure a numeric sort; not ASCII-betical
	my $timeInterval = parseInterval( seconds => $key );
	if ( $key < $binThreshold + 1 ) {
		print "< ";
	} else {
		print "> ";
	}
	#print $timeInterval->{'hours'} . 'h ' . $timeInterval->{'minutes'} . 'm: ' . $histogramData{ $key } . "\n";
	print $timeInterval->{'days'} . 'd: ' . $histogramData{ $key } . "\n";
}

print "\nTOTAL TICKETS: $totalTickets\n";
print "\nSKIPPED TICKETS: $skippedTickets\n\n";
