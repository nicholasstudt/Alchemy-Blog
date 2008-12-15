#!/usr/bin/perl -w
######################################################################
# $Id: blog_roll.pl,v 1.7 2005/03/20 20:32:47 nstudt Exp $
# $Date: 2005/03/20 20:32:47 $
######################################################################
use strict;
use Getopt::Long; 
use File::Temp qw( tempfile );
use LWP::UserAgent;
use POSIX qw( strftime );
use XML::Parser;

use KrKit::HTML qw( :all );
use KrKit::Validate;

use vars qw( $timefmt $epoch @output );

############################################################
# Variables                                                #
############################################################

############################################################
# Functions                                                #
############################################################

#------------------------------------------------
# help()
#------------------------------------------------
sub help () {
	
	print 	"USAGE: $0 [options]\n",
			"    --help                Display this usage\n", 
			"    --output <file>       Output file\n",
			"    --timefmt <fmt>       Time Format (in strftime)\n", 
			"    --userid <userid>     blo.gs user id\n";
	
	exit;
} # END help

#------------------------------------------------
# weblogUpdates()
#------------------------------------------------
sub weblogUpdates { 
	my ( $expat, $element, %stuff ) = @_;

	# Set the time for use in weblog()
	$epoch = $stuff{count};

} # END weblogUpdates

#------------------------------------------------
# weblog()
#------------------------------------------------
sub weblog {
	my ( $expat, $element, %stu ) = @_;

	push( @output, 	ht_div( { 'class' => 'rolled' } ),
					ht_a( $stu{url}, $stu{name} ),
					ht_span( { 'class' => 'date' },  
							strftime( 	$timefmt, 
										localtime($epoch - $stu{when}) ) ),
					ht_udiv() );
} # END weblog

######################################################################
# Main Execution Begins Here                                         #
######################################################################
eval {
	my %opt = ( 'output' 	=> 'output.html',
				'timefmt' 	=> '%b %d, %H:%M %Z',
				'userid'	=> '' ); 
	
	GetOptions( 'help'		=> sub { help() },
				'output=s'	=> \$opt{output},
				'timefmt=s'	=> \$opt{timefmt},
				'userid=s'	=> \$opt{userid} );

	# So that everyone can see it.
	$timefmt = $opt{timefmt};

	if ( ! is_integer( $opt{userid} ) ) {
		print "Error: no userid specified\n";
		exit;
	}

	# Grab the new file from blo.gs
	my $url	= 'http://blo.gs/'. $opt{userid}. '/favorites.xml';
	my $ua 	= LWP::UserAgent->new();
	my $req = HTTP::Request->new( GET => $url );
	my $res = $ua->request( $req );

	if ( $res->is_success ) {
	
		my ( $fh, $filename ) = tempfile( 'UNLINK' => 1 );

		$fh->print( $res->content."\n" );
		$fh->flush();

		my $p1 = XML::Parser->new( 'Style' => 'Subs' );

		$p1->parsefile( $filename );
	
		if ( open( FILE, ">:utf8", $opt{output} ) ) {
		
			print FILE join( "\n", 	ht_div( { 'class' => 'roll' } ), 
									@output, 
									ht_udiv(), "\n" );
	
			close( FILE );
		} 
	}
	else {
		print "Error: Unable to retrieve favorites.xml\n";
	}

};

print "Error: $@\n\n" if ( $@ );

# EOF 
1;

__END__

=head1 NAME 

blog_roll.pl - blo.gs blog roll generator.

=head1 SYNOPSIS

  USAGE: blog_roll.pl [options]
    --help                Display this usage
    --output <file>       Output file
    --timefmt <fmt>       Time Format (in strftime)
    --userid <userid>     blo.gs user id

=head1 DESCRIPTION

This script will generate a blog roll based on the favorites for the
user on blo.gs. This script should not be run more than once an hour or
the blo.gs people may ban the requesting ip address.

=head1 SEE ALSO

Alchemy::Blog(3)

=head1 LIMITATIONS 

=head1 AUTHOR

Nicholas Studt <nstudt@angrydwarf.org>

=head1 COPYRIGHT

Copyright (c) 2004 Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
