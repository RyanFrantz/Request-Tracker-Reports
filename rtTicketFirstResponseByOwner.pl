#!/usr/bin/perl

#
# rtTicketFirstResponseByOwner.pl - query RT and generate a report on how long it took to respond to a request by ticket owner
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

my $currentUser = GetCurrentUser();
my @supportDeskTechs = (
	'foo',
	'bar',
	'baz',
);

my %histogramData;
my $binThreshold = '7200';	# 2 hours, in seconds
my $numAboveBinThreshold;

sub doIt {
	my $owner = shift;
	$numAboveBinThreshold = '0';	# ensure this is "cleared" to zero
	my $tickets = RT::Tickets->new( $currentUser );
	#my $query = qq[ Created > '7 days ago' AND ( Queue = 'Support Desk (Level 1)' OR Queue = 'Support Desk (Level 2)' ) AND Status = 'resolved' ];
	my $query = qq[ Created > '7 days ago' AND ( Queue = 'Support Desk (Level 1)' OR Queue = 'Support Desk (Level 2)' ) AND Status = 'resolved' AND Owner = '$owner' ];

	# define the response times for each bin; in seconds
	#my %histogramData = (
	%histogramData = (
		'900'	=>	'0',	# 15min
		'1800'	=>	'0',	# 30min
		'2700'	=>	'0',	# 45min
		'3600'	=>	'0',	# 1hour
		'4500'	=>	'0',	# 1hour15min
		'5400'	=>	'0',	# 1hour30min
		'6300'	=>	'0',	# 1hour45min
		$binThreshold	=>	'0',	# 2hours
		#'more'	=>	'0'	# $binThreshold + 1; we'll add this key in at the end
	);

sub tallyResponseTime {
# TODO: update to accept the owner name and key on that

	my $responseTime = shift;
	#print "\nTEST VALUE: $responseTime\n";	# debug
	my $rangeLowerBound = '0';

	foreach my $binResponseTime ( sort { $a <=> $b } keys %histogramData ) {	# ensure a numeric sort; not ASCII-betical
		if ( $responseTime >= $rangeLowerBound and $responseTime < $binResponseTime ) {
			$histogramData{ $binResponseTime }++;
			last;   # no need to continue
		} elsif ( $responseTime > $binThreshold ) {
			$numAboveBinThreshold++;	# we'll add this value to a 'more' key in the hash at the end of the script
			last;
		}

		$rangeLowerBound = $binResponseTime;
	}

}	# end tallyResponseTime()

	my $validQuery = $tickets->FromSQL( $query );
	#print "VALID QUERY!\n" if $validQuery;	# debug

	# compare the ticket Created and Started times to determine response time
	my $totalTickets = '0';
	while ( my $ticket = $tickets->Next() ) {

		my $dateTicketCreated = $ticket->CreatedObj->Get( Timezone => 'server' );
		my @dateTicketCreated = split( /-|:| /, $dateTicketCreated );
		my $timeTicketCreated = Date_to_Time( @dateTicketCreated );	# seconds since epoch
		my $dateTicketStarted = $ticket->StartedObj->Get( Timezone => 'server' );
		my @dateTicketStarted = split( /-|:| /, $dateTicketStarted );
		my $timeTicketStarted = Date_to_Time( @dateTicketStarted );	# seconds since epoch
		my $timeDiff = $timeTicketStarted - $timeTicketCreated;

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
		print $timeInterval->{'hours'} . 'h ' . $timeInterval->{'minutes'} . 'm: ' . $histogramData{ $key } . "\n";
	}

	print "\nTOTAL TICKETS: $totalTickets\n\n";

} # end doIt()

foreach my $owner ( @supportDeskTechs ) {
	print "(OWNER: $owner)\n";
	doIt( $owner );
}
