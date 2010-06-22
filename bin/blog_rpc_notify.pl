#!/usr/bin/perl -w
######################################################################
# $Id: blog_rpc_notify.pl,v 1.7 2004/12/23 16:07:13 nstudt Exp $
# $Date: 2004/12/23 16:07:13 $
######################################################################
use strict;
use Getopt::Long; 
use XMLRPC::Lite;
use POSIX qw( strftime );

use KrKit::DB;
use KrKit::SQL;
use KrKit::Validate;

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
	
	print 	"USAGE: $0 [options] <username to purge>\n\n",
			"    --help                Display this usage\n", 
			"    --dbtype <type>       Database type\n",
			"    --dbsrv <server>      Database server\n",
			"    --dbname <name>       Database name\n", 
			"    --dbuser <user>       Database username\n", 
			"    --dbpass <password>   Database password\n",
			"    --blogname <name>     Blog name\n",
			"    --bloguri <uri>       URI to the blog\n",
			"    --blogrss <uri>       URI to the blog's RSS feed\n",
			"    --period <period>     Period to check for new articles\n",
			"    --verbose             Be verbose\n";
	
	exit;
} # END help

######################################################################
# Main Execution Begins Here                                         #
######################################################################
eval {
	my %opt = ( 'dbtype'	=> 'Pg',
				'dbsrv'		=> '',
				'dbname'	=> '',
				'dbuser'	=> 'apache',
				'dbpass'	=> '',
				'blogname' 	=> '',
				'bloguri'	=> '',
				'blogrss'	=> '',
				'period'	=> '60',
				'verbose'	=> '0' ); 
	
	GetOptions( 'help'			=> sub { help() },
				'dbtype=s'		=> \$opt{dbtype},
				'dbsrv=s'		=> \$opt{dbsrv},
				'dbname=s'		=> \$opt{dbname},
				'dbuser=s'		=> \$opt{dbuser},
				'dbpass=s'		=> \$opt{dbpass}, 
				'blogname=s' 	=> \$opt{blogname},
				'bloguri=s'		=> \$opt{bloguri},
				'blogrss=s'		=> \$opt{blogrss},
				'period=i'		=> \$opt{period},
				'verbose+'		=> \$opt{verbose} );

	# Catch the no user time.
	if ( ! is_integer( $opt{period} ) ) {
		print "Invalid period\n";
		exit;
	}

	if ( ! is_text( $opt{blogname} ) ) {
		print "No blogname\n";
		exit;
	}
	
	if ( ! is_text( $opt{bloguri} ) ) {
		print "No bloguri\n";
		exit;
	}

	# Connect to the db.
	$opt{dbh} = db_connect( $opt{dbtype}, $opt{dbuser}, $opt{dbpass}, 
						 	$opt{dbsrv}, $opt{dbname}, 'off' );

	my $now = strftime( "%F %I:%M:%S %p", 
						localtime( time - ( 60 * $opt{period} ) ) );

	# FIXME: Look up the info based on the section.


	# check for an article that posted in the last x period.
	my $sth = db_query( $opt{dbh}, 'look for update',
						'SELECT count( bg_articles.id ) FROM bg_articles, ',
						'bg_article_type WHERE bg_article_type.id = ',
						'bg_article_type_id AND published =\'t\' AND ',
						'pub_date BETWEEN ', sql_str( $now ), 'AND \'now\'' );

	my ( $id ) = db_next( $sth );

	db_finish( $sth );
	
	db_disconnect( $opt{dbh} );

	if ( $id ) {
		my @send 	= ( $opt{blogname}, $opt{bloguri}, $opt{bloguri}, 
						$opt{blogrss} );
		my $xmlcall = XMLRPC::Lite 
								->proxy( 'http://ping.blo.gs/' )
								->call( 'weblogUpdates.extendedPing', @send );

		# Not much to do if it fails right now.
   		#my $status = $xmlcall->result;
	}
};

print "Error: $@\n\n" if ( $@ );

# EOF 
1;

__END__

=head1 NAME 

blog_rpc_notify.pl -- blo.gs ping script.

=head1 SYNOPSIS

  USAGE: blog_rpc_notify.pl [options]
    
    --help                Display this usage
    --dbtype <type>       Database type
    --dbsrv <server>      Database server
    --dbname <name>       Database name
    --dbuser <user>       Database username
    --dbpass <password>   Database password
    --blogname <name>     Blog name
    --bloguri <uri>       URI to the blog
    --blogrss <uri>       URI to the blog's RSS feed
    --period <period>     Period to check for new articles
    --verbose             Be verbose
	
=head1 DESCRIPTION

This script notifies blo.gs of new articles in the database.

=head1 DATABASE

This module reads from the Alchemy::Blog database tables.

=head1 SEE ALSO

Alchemy::Blog(3)

=head1 LIMITATIONS 

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 2004 Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
