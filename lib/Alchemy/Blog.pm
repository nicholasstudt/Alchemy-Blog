package Alchemy::Blog;
######################################################################
# $Id: Blog.pm,v 1.36 2005/09/02 14:05:29 nstudt Exp $
# $Date: 2005/09/02 14:05:29 $
######################################################################
use strict;
use Apache2::RequestRec;

use KrKit::Control;
use KrKit::DB;
use KrKit::Handler;
use KrKit::HTML qw( :all );
use KrKit::SQL;
use KrKit::Validate;

############################################################
# Variables                                                #
############################################################
our $VERSION = '0.43';
our @ISA = ( 'KrKit::Handler' );

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# $k->_init( $r )
#-------------------------------------------------
sub _init {
	my ( $k, $r ) = @_;

	$k->SUPER::_init( $r );

	$$k{'hostname'}		= $r->hostname;

	# FIXME: Move these to database based variables.
	$$k{'default_sect'}	= $r->dir_config( 'Blog_Default_Section' );
	$$k{'ident_length'} 	= $r->dir_config( 'Blog_Ident_Length' ) || '20';
	$$k{'force_auth'} 	= $r->dir_config( 'Blog_Auth_Names' ) || 0;
	$$k{'post_time'} 	= $r->dir_config( 'Blog_Post_Days' ) || 0;
	$$k{'post_inline'} 	= $r->dir_config( 'Blog_Post_Inline' ) || 0;
	$$k{'most_recent'} 	= $r->dir_config( 'Blog_Recent_Show' ) || 10;

	$$k{'cookie_name'} 	= $r->dir_config( 'Blog_Cookie_Name' ) || 'blog';
	$$k{'cookie_path'} 	= $r->dir_config( 'Blog_Cookie_Path' ) || '/';
	$$k{'cookie_expire'} = $r->dir_config( 'Blog_Cookie_Expire' ) || undef;

	# Public Roots
	$$k{'root_blog'}		= $r->dir_config( 'Blog_Viewer_Root' );
	$$k{'root_synd'} 	= $r->dir_config( 'Blog_Synd_Root' );
	$$k{'root_posts'} 	= $r->dir_config( 'Blog_Posts_Root' );

	# Admin Roots
	$$k{'root_article'} 	= $r->dir_config( 'Blog_Article_Root' );
	$$k{'root_author'} 	= $r->dir_config( 'Blog_Author_Root' );
	$$k{'root_type'} 	= $r->dir_config( 'Blog_Type_Root' );
	$$k{'root_section'} 	= $r->dir_config( 'Blog_Section_Root' );
	$$k{'root_comment'} 	= $r->dir_config( 'Blog_Comment_Root' );
	$$k{'root_category'}	= $r->dir_config( 'Blog_Category_Root' );

	$$k{rootp} = '' if ( $$k{rootp} eq '/' );

	# Must happen at last moment before needed. ( after frame is set )
	$$k{'userid'} 		= 0;
	$$k{'username'} 		= $r->user();

	if ( is_text( $$k{username} ) ) {
		$$k{userid} = (get_pwnam( $$k{dbh}, $$k{username}))[0];
	}

	return();
} # END $k->_init

#-------------------------------------------------
# $k->author_info( $author_id )
#-------------------------------------------------
sub author_info {
	my ( $k, $author_id ) = @_;

	return( 'Unknown', 'unknown' ) if ( ! is_number( $author_id ) );

	my $ath = db_query( $$k{dbh}, 'get author', 
						'SELECT name, ident FROM bg_authors WHERE id=',
						sql_num( $author_id ) );
		
	my ( $author, $aident ) = db_next( $ath );

	db_finish( $ath );

	return( $author, $aident );
} # END $k->author_info

#-------------------------------------------------
# $k->sanitize_text( $text )
#-------------------------------------------------
sub sanitize_text {
	my ( $k, $text ) = @_;

	return( '' ) if ( ! is_text( $text ) );

	my @output;

	$text =~ s/(\r\n)|\r/\n/g;

	# Split on newlines, sanitize, do links.
	for my $txt ( split( /\n+/, $text ) ) {

		next if ( ! defined $txt );

		$txt = ht_qt( $txt );

		$txt =~ s|\s?(https?://[\[\]:a-z\-0-9/~._,\#=;?&%+]+[a-z\-0-9/_~+])
				 |<a href="$1">$1</a>|gimx;

	  	$txt =~ s|\s?(www\.[\[\]:a-z\-0-9/~._,\#=;?&]+\.[a-z\-0-9/_~]+)
				 |<a href="http://$1">$1</a>|gimx;

	  	$txt =~ s|\s?(ftp://[a-z\-0-9/~._,]+[a-z\-0-9/_~])
				 |<a href="$1">$1</a>|gimx;

		$txt =~ s/^\s+//g;
		$txt =~ s/\s+$//g;

		push( @output, ht_p(), $txt, ht_up() );
	}

	return( join( ' ', @output ) );
} # END $k->sanitize_text

#-------------------------------------------------
# $k->section_info( $section )
#-------------------------------------------------
sub section_info {
	my ( $k, $section ) = @_;

	return( undef ) if ( ! is_text( $section ) );

	my $ath = db_query( $$k{dbh}, 'get section id',
						'SELECT id, article_limit, s_options, name, frame, ',
						'description FROM bg_sections WHERE ident = ', 
						sql_str( $section ) );

	my ( $sid, $salim, $sopt, $sname, $sframe, $sdesc ) = db_next($ath);

	db_finish( $ath );

	return( $sid, $salim, $sopt, $sname, $sframe, $sdesc );
} # END $k->section_info

# EOF
1;

__END__

=head1 NAME 

Alchemy::Blog - Blog application.

=head1 DESCRIPTION

This application is designed to be used as a blog. It may have limited
use as a "news" application allowing new articles to be posted and an
archive to be purused.

=head1 MODULES

=over 4

=item Alchemy::Blog::Article

This module is the administrative interface for blog articles, this is
the main section of the blog that authors will actually use to post
content.

=item Alchemy::Blog::Article::Type

This module manages the article types that are used for articles.

=item Alchemy::Blog::Article::Author

This module manages authors that may be assigned to articles.

=item Alchemy::Blog::Section

=item Alchemy::Blog::Section::Category

This module manages categories for the system.

=item Alchemy::Blog::Viewer

This is the front end for this application, what the general public will
see. 

=item Alchemy::Blog::Viewer::Comments

This module allows the viewing and posting of comments.

=item Alchemy::Blog::Viewer::Syndication

This module provides RSS syndication.

=back

=head1 CONFIGURATION

FIXME: Add how to configure this application.

=head1 METHODS

=over 4

=item $self->_init( $r )

Called by the core handler to initialize each page request.

=back

=head1 SEE ALSO

KrKit(3), perl(3)

=head1 LIMITATIONS

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 2003 Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
