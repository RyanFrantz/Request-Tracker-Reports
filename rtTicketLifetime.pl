#!/usr/bin/perl

#
# rtTicketLifetime.pl - query RT and generate a report on the lifetime of resolved tickets
#

use strict;
use warnings;

use lib "/usr/local/rt/lib";

use RT;
use RT::User;
use RT::Interface::CLI qw( CleanEnv GetCurrentUser );	# I guess these aren't exported?

use Date::Calc qw( Delta_DHMS );

# TODO:
# 1. add a break out of ticket lifetime by owner
# 2. add email support
# 3. make this available via the web interface with graphing goodness

## start me up!

# set the stage...
CleanEnv();
RT::LoadConfig;
RT::Init;

my $currentUser = GetCurrentUser();
my $tickets = RT::Tickets->new( $currentUser );
my $query = qq[ Created > '7 days ago' AND ( Queue = 'Support Desk (Level 1)' OR Queue = 'Support Desk (Level 2)' ) AND Status = 'resolved' ];

my $validQuery = $tickets->FromSQL( $query );
#print "VALID QUERY!\n" if $validQuery;

my $binThreshold = '7';	# 7 days, trust me...
my @histogramData;	# prep dat
# initialize the bins, in case there are any that don't get incremented later
# we'll use the array's indices to define the time period in which the ticket lived (i.e. $histogramData[0] is for tickets resolved in < 1 day)
foreach my $day ( 0..$binThreshold ) {
	$histogramData[ $day ] = '0';
}

while ( my $ticket = $tickets->Next() ) {
	#my $owner = $ticket->OwnerObj;	# we're not using this yet...

	# CreatedObj is available via RT::Record
	my $dateCreated = $ticket->CreatedObj->Get( Timezone => 'server' );
	my $dateResolved = $ticket->ResolvedObj->Get( Timezone => 'server' );
	my @dateCreated = split( /-|:| /, $dateCreated );
	my @dateResolved = split( /-|:| /, $dateResolved );
	my ( $deltaDays, $deltaHours, $deltaMinutes, $deltaSeconds ) = Delta_DHMS( @dateCreated, @dateResolved );

	# increment the bins; if the value is above the bin threshold, simply lump it into a "more" bin ( $binThreshold )
	if ( $deltaDays > $binThreshold ) {
		#print "DEBUG: $deltaDays > $binThreshold\n";
		$histogramData[ $binThreshold ]++;
	} else {
		#print "DEBUG: $deltaDays <= $binThreshold\n";
		$histogramData[ $deltaDays ]++;
	}
}

print "\n" . localtime() . "\n";
print "\nQuery: $query\n";
print "\nFound " . $tickets->CountAll . " tickets\n\n";

my $day = '1';
foreach my $ticketsResolved ( @histogramData ) {
	if ( $day <= $binThreshold ) {
		print $day - 1 . " < " . $day . ": " . $ticketsResolved . "\n";
	} else {
		print $day . "+ : " . $ticketsResolved . "\n";
	}
	$day++;
}
print "\n";
