#!/usr/bin/perl

#
# rtTicketTimeWorked.pl - query RT and generate a report on the time worked for resolved tickets
#

use strict;
use warnings;

use lib "/usr/local/rt/lib";

use RT;
use RT::User;
use RT::Interface::CLI qw( CleanEnv GetCurrentUser );	# I guess these aren't exported?

use Date::Calc qw( Delta_DHMS );
use Time::Interval;

## start me up!

# set the stage...
CleanEnv();
RT::LoadConfig;
RT::Init;

my $currentUser = GetCurrentUser();
my $tickets = RT::Tickets->new( $currentUser );
my $query = qq[ Created > '7 days ago' AND ( Queue = 'Support Desk (Level 1)' OR Queue = 'Support Desk (Level 2)' ) AND Status = 'resolved' ];
#my $query = qq[ Created > '2011-09-19' AND ( Queue = 'Support Desk (Level 1)' OR Queue = 'Support Desk (Level 2)' ) AND Status = 'resolved' ];

my $validQuery = $tickets->FromSQL( $query );
#print "VALID QUERY!\n" if $validQuery;

#my $timeWorkedByCategory = {};
my %timeWorkedByCategory;
my $totalTimeWorked = '0';
while ( my $ticket = $tickets->Next() ) {
	#my $owner = $ticket->OwnerObj;	# we're not using this yet...

	# CreatedObj is available via RT::Record
	my $dateCreated = $ticket->CreatedObj->Get( Timezone => 'server' );
	my $dateResolved = $ticket->ResolvedObj->Get( Timezone => 'server' );
	my @dateCreated = split( /-|:| /, $dateCreated );
	my @dateResolved = split( /-|:| /, $dateResolved );
	my ( $deltaDays, $deltaHours, $deltaMinutes, $deltaSeconds ) = Delta_DHMS( @dateCreated, @dateResolved );
	my $timeWorked = $ticket->TimeWorked;
	$totalTimeWorked += $timeWorked;
	#print $ticket->Id . " TIME WORKED: " . $timeWorked . "\n";	# debug

	my $category = $ticket->FirstCustomFieldValue( 'Category' );
	if ( $category ) {
		#print "CATEGORY: " . $category . "\n\n";	# debug
		$timeWorkedByCategory{ $category }{ 'numTickets' }++;
		$timeWorkedByCategory{ $category }{ 'totalTimeWorked' } += $timeWorked;
	} else {
		#print "CATEGORY: NOT SET\n\n";	# debug
		$timeWorkedByCategory{ 'NOT SET' }{ 'numTickets' }++;
		$timeWorkedByCategory{ 'NOT SET' }{ 'totalTimeWorked' } += $timeWorked;
	}

}

print "\n" . localtime() . "\n";
print "\nQuery: $query\n";
print "\nFound " . $tickets->CountAll . " tickets\n\n";
#print "TOTAL TIME WORKED: $totalTimeWorked\n";
my $timeInterval = parseInterval( minutes => $totalTimeWorked );
print "TIME WORKED: " . $timeInterval->{'hours'} . 'h ' . $timeInterval->{'minutes'} . 'm ' . "\n";


foreach my $category ( sort keys %timeWorkedByCategory ) {
	print "\n" . $category . "\n";
	my $numTix =  $timeWorkedByCategory{ $category }{ 'numTickets' }; 
	my $totalTimeWorked =  $timeWorkedByCategory{ $category }{ 'totalTimeWorked' };
	my $average = sprintf( "%.1f", $totalTimeWorked / $numTix );
	print "AVG: " . $average . " min\n";
}
