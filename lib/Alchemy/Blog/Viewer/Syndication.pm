package Alchemy::Blog::Viewer::Syndication;
######################################################################
# $Id: Syndication.pm,v 1.8 2005/06/10 17:51:48 nstudt Exp $
# $Date: 2005/06/10 17:51:48 $
######################################################################
use strict;

use POSIX qw( strftime );
use XML::RSS;

use KrKit::DB;
use KrKit::Handler;
use KrKit::HTML qw( :all );
use KrKit::SQL;
use KrKit::Validate;

use Alchemy::Blog;

use vars qw( @ISA );

############################################################
# Variables                                                #
############################################################
@ISA = ( 'Alchemy::Blog', 'KrKit::Handler' );

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# $site->do_main( $r, $section, $category )
#-------------------------------------------------
sub do_main {
	my ( $site, $r, $section, $category ) = @_;

	# Get the defaults before we proceed.
	$$site{contenttype} = 'application/xml';
	$$site{frame}		= 'none';
	$section 			= $$site{default_sect} if ( ! is_ident( $section ) );

	my ( $count, $limit, $name, $desc )	= ( 0, 5, '', '' );

	my @where;
	my $link 	= "http://$$site{hostname}$$site{root_blog}";
	my @from 	= ( 'bg_articles', 'bg_article_type' );

	# Find section information.
	my $ath = db_query( $$site{dbh}, 'get section id',
						'SELECT id, name, article_limit, language,',
						'description FROM bg_sections WHERE ident = ', 
						sql_str( $section ) );
	
	my ( $sid, $sname, $salim, $slang, $sdesc ) = db_next( $ath ) ;

	db_finish( $ath );

	return( $site->_decline() ) if ( ! is_number( $sid ) );

	# Get category Information if needed
	if ( is_ident( $category ) ) {

		my $bth = db_query( $$site{dbh}, 'get category info',
							'SELECT id, article_limit, name, description ',
							'FROM bg_categories WHERE bg_section_id = ', 
							sql_num( $sid ), ' AND ident = ',
							sql_str( $category ) );

		my ( $cid, $calim, $cname, $cdesc ) = db_next( $bth );

		db_finish( $bth );
	
		return( $site->_decline() ) if ( ! is_number( $cid ) );

		$link 	.= "/category/$section/$category";
		$name 	= "$sname -- $cname";
		$desc 	= ( defined $cdesc ) ? $cdesc : $sdesc;
		$limit 	= $calim;

		push( @from, 	'bg_article_categories' );
		push( @where, 	'bg_article_id = bg_articles.id ',
						'bg_category_id = '. sql_num( $cid ) );
	}
	else {

		# This keeps the ugly url at bay.
		$link 	.= "/main/$section" if ( $section ne $$site{default_sect} );
		$name 	= $sname;
		$desc 	= $sdesc;
		$limit 	= $salim;
		
		push( @where, 'bg_section_id = '. sql_num( $sid ) );
	}

	# Actually generate the RSS feed.
	my $rss = XML::RSS->new( version => '2.0' );

	$rss->channel( 	'title' 		=> $name, 
					'link'			=> $link,
					'language'		=> $slang,
					'description' 	=> $desc );

	my $sth = db_query( $$site{dbh}, 'get articles',
						'SELECT bg_articles.id, bg_articles.ident, ',
						'bg_author_id, topic, ',
						'date_part( \'epoch\', pub_date ), summary ',
						'FROM ', join( ', ', @from ),
						'WHERE bg_article_type.id = bg_article_type_id ',
						'AND published =\'t\' AND pub_date <= \'now\' ',
						'AND ', join( ' AND ', @where ),
						'ORDER BY pub_date DESC ' );

	while ( my( $id, $ident, $aid, $topic, $date, 
				$summary ) = db_next( $sth ) ) {

		$count++;

		next if ( $limit > 0 && $count > $limit );

		# Grab author stuff.
		my $ath = db_query( $$site{dbh}, 'get author', 
							'SELECT name, email FROM bg_authors ',
							'WHERE id = ', sql_num( $aid ) );
		
		my ( $author, $email ) = db_next( $ath );

		db_finish( $ath );

		my @cats;

		my $bth = db_query( $$site{dbh}, 'get categories', 
							'SELECT name FROM bg_categories, ',
							'bg_article_categories WHERE ',
							'bg_categories.id = bg_category_id AND ',
							'bg_article_id = ', sql_num( $id )  );

		while ( my ( $cname ) = db_next( $bth ) ) {
			push( @cats, $cname );
		}

		db_finish( $bth );

		my $rdate 	= strftime( "%a, %d %b %Y %H:%M:%S %z", localtime($date) );
		my $ldate 	= strftime( "%Y-%m-%d", localtime( $date ) );
		my $alink 	= 	"http://$$site{hostname}".
						"$$site{root_blog}/article/$section/$ldate/$ident";
		$summary 	=~ s/>/&gt;/g;
		$summary 	=~ s/</&lt;/g;
		$summary 	=~ s/&middot;/&#183;/g;
		$topic 		=~ s/>/&gt;/g;
		$topic 		=~ s/</&lt;/g;

		$rss->add_item( 'title' 		=> $topic,
						'link'			=> $alink,
						'author'		=> "$email ($author)",
						'category' 		=> join( ', ', @cats ),
						'pubDate' 		=> $rdate,
						'description' 	=> $summary );
	}

	db_finish( $sth );

	return( $rss->as_string );
} # END $site->do_main

# EOF
1;

__END__

=head1 NAME 

Alchemy::Blog::Viewer::Syndication - Public blog syndication

=head1 SYNOPSIS

  use Alchemy::Blog::Viewer::Syndication;

=head1 DESCRIPTION

This module provides RSS syndication.

=head1 APACHE

This is a sample of the location required for this module to run.
Consult Alchemy::Blog(3) to learn about the configuration options.

  <Location / >
    SetHandler  perl-script

    PerlHandler Alchemy::Blog::Viewer::Syndication
  </Location>

=head1 DATABASE

This module reads from all of the blog tables. It does not modify these
tables.

=head1 SEE ALSO

Alchemy::Blog(3), Alchemy(3), KrKit(3)

=head1 LIMITATIONS

=head1 AUTHOR

Nicholas Studt <nstudt@angrydwarf.org>

=head1 COPYRIGHT

Copyright (c) 2003-2004 Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
