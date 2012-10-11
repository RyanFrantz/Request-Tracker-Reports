#!/usr/bin/perl

#
# rtTicketFirstResponseByCategory.pl - query RT and generate a report on how long it took to respond to requests, by category
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
my $query = qq[ Created > '7 days ago' AND ( Queue = 'Support Desk (Level 1)' OR Queue = 'Support Desk (Level 2)' ) AND Status = 'resolved' ];

my $binThreshold = '7200';	# 2 hours, in seconds
# define the response times for each bin; in seconds
my %histogramData = (
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

my %bigUnamedBucket;
my $numAboveBinThreshold;
sub tallyResponseTime {

	my $category = shift;
	my $responseTime = shift;
	#print "\nTEST VALUE: $responseTime\n";	# debug
	my $rangeLowerBound = '0';

	unless ( exists $bigUnamedBucket{ $category } ) {
		# create the empty bins for this category
		foreach my $key ( keys %histogramData ) {
			$bigUnamedBucket{ $category }{ $key } = '0';
		}
	}
	foreach my $binResponseTime ( sort { $a <=> $b } keys %histogramData ) {	# ensure a numeric sort; not ASCII-betical
		if ( $responseTime >= $rangeLowerBound and $responseTime < $binResponseTime ) {
			$bigUnamedBucket{ $category }{ $binResponseTime }++;
			last;   # no need to continue
		} elsif ( $responseTime > $binThreshold ) {
			$numAboveBinThreshold++;	# we'll add this value to a 'more' key in the hash at the end of the script
			last;
		}

		$rangeLowerBound = $binResponseTime;
	}

}	# end tallyResponseTime()

my $totalTickets = '0';
sub queryTickets {
	my $tickets = RT::Tickets->new( $currentUser );
	my $validQuery = $tickets->FromSQL( $query );
	#print "VALID QUERY!\n" if $validQuery;	# debug

	# compare the ticket Created and Started times to determine response time
	while ( my $ticket = $tickets->Next() ) {
		my $dateTicketCreated = $ticket->CreatedObj->Get( Timezone => 'server' );
		my @dateTicketCreated = split( /-|:| /, $dateTicketCreated );
		my $timeTicketCreated = Date_to_Time( @dateTicketCreated );	# seconds since epoch
		my $dateTicketStarted = $ticket->StartedObj->Get( Timezone => 'server' );
		my @dateTicketStarted = split( /-|:| /, $dateTicketStarted );
		my $timeTicketStarted = Date_to_Time( @dateTicketStarted );	# seconds since epoch
		my $timeDiff = $timeTicketStarted - $timeTicketCreated;

		my $category = $ticket->FirstCustomFieldValue( 'Category' );
		$category = 'NOT SET' unless $category;
		tallyResponseTime( $category, $timeDiff );
		$totalTickets++;
	}

	# after all tallies, add the key/value pair for those tickets whose response time was above our bin threshold
	$histogramData{ $binThreshold + 1 } = $numAboveBinThreshold || '0';	# 7201 seconds; NOTE: there may be none at this level, default to '0'

}	# end queryTickets()

queryTickets();

# report!
print "\n" . localtime() . "\n";
print "\nQUERY: $query\n\n";
foreach my $category ( sort keys %bigUnamedBucket ) {
	print "\n$category\n";
	foreach my $key ( sort { $a <=> $b } keys %{ $bigUnamedBucket{ $category } } ) {    # ensure a numeric sort; not ASCII-betical
		my $timeInterval = parseInterval( seconds => $key );
		if ( $key < $binThreshold + 1 ) {
			print "< ";
		} else {
			print "> ";
		}
		print $timeInterval->{'hours'} . 'h ' . $timeInterval->{'minutes'} . 'm: ' .  $bigUnamedBucket{ $category }{$key} . "\n";
	}
}

print "\nTOTAL TICKETS: $totalTickets\n\n";
