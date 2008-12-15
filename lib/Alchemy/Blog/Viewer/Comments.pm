package Alchemy::Blog::Viewer::Comments;
######################################################################
# $Id: Comments.pm,v 1.18 2005/09/02 14:05:29 nstudt Exp $
# $Date: 2005/09/02 14:05:29 $
######################################################################
use strict;

use POSIX qw( strftime );

use KrKit::AppBase;
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
# comment_checkvals( $site, $in ) 
#-------------------------------------------------
sub comment_checkvals {
	my ( $site, $in ) = @_;

	my @errors;

	if ( ! is_text( $in->{name} ) ) {
		push( @errors, 'Please enter your name.', ht_br() );
	}

	if ( ! is_email( $in->{email} ) ) {
		push( @errors, 'Please enter your e-mail address.', ht_br() );
	}

	if ( is_text( $in->{url} ) ) {
		if ( $in->{url} !~ /^http(s?):\/\// ) {
			push( @errors, 'A URL must start with "http://".', ht_br() );
		}
	}

	if ( ! is_text( $in->{comment} ) ) {
		push( @errors, 'Please enter your comment.', ht_br() );
	}

	return( @errors );
} # END comment_checkvals

#-------------------------------------------------
# comment_form( $site, $in, $view )
#-------------------------------------------------
sub comment_form {
	my ( $site, $in, $view ) = @_;

	my ( @preview, @button );

	if ( defined $view && $view ) {
		my $comment = $site->sanitize_text( $in->{comment} );
		my $cname 	= $in->{name} || '';
		$cname 		= ht_a( $in->{url}, $cname ) if ( is_text( $in->{url} ) );

		push( @preview, ht_div( { 'class' => 'comment' } ),
							qq!<h1>$cname says:</h1>!,
							ht_div( { 'class' => 'commentbody' }, $comment ),
							ht_div( { 'class' => 'commenttime' }, 'Posted on ', 
									strftime( 	$$site{fmt_dt}, 
												localtime() ) ),	
						ht_udiv() );

		push( @button, ht_submit( 'post', 'Post comment' ) );
	}

	return( @preview,
	
			ht_form_js( $$site{uri} ),	
			ht_div( { 'class' => 'comment_post' } ),
			ht_table( {} ),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Name' ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'name', 'text', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'E-mail' ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'email', 'text', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'URL' ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'url', 'text', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Comment' ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 	'comment', 'textarea', $in, 
								'rows="5" cols="40"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd', colspan => '2' }, 
					'Remember me', ht_checkbox( 'cookie', 1, $in ) ),
			ht_utr(),
		
			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Preview comment' ), @button ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END comment_form

#-------------------------------------------------
# $site->do_add( $r, $section, $article_date, $ident )
#-------------------------------------------------
sub do_add {
	my ( $site, $r, $section, $adate, $ident ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title}	.= 'Comment Preview';

	return( $site->_decline() ) if ( ! is_text( $section ) );
	return( $site->_decline() ) if ( ! is_text( $adate ) );
	return( $site->_decline() ) if ( ! is_text( $ident ) );

	# Verify the section
	my ( $sid, $sname, $sframe ) = ( $site->section_info( $section ) )[0,3,4];
	
	return( $site->_decline() ) if ( ! is_number( $sid ) );

	# Verify the ident and the date.
	my ( $year, $month, $day ) = split( '-', $adate );

	return( $site->_decline() ) if ( ! is_date( "$month-$day-$year" ) );

	my $sth = db_query( $$site{dbh}, 'get article',
						'SELECT bg_articles.id, a_options, ',
						'topic, comment_count FROM bg_articles, ',
						'bg_article_type WHERE ',
						'bg_article_type.id = bg_article_type_id ',
						'AND published =\'t\' AND pub_date BETWEEN ',
						sql_str( "$year-$month-$day 00:00:00" ), ' AND ', 
						sql_str( "$year-$month-$day 23:59:59" ),
						'AND pub_date <= \'now\'', 
						'AND bg_articles.ident = ', sql_str( $ident ),
						'AND bg_section_id = ', sql_num( $sid ) );

	my ( $id, $opts, $topic, $ccount ) = db_next( $sth );

	db_finish( $sth );

	return( $site->_decline() ) if ( ! is_number( $id ) );

	return( $site->_decline() ) if ( ! ( $opts & 1 || $opts & 2 ) );

	$$site{page_title} .= 'Comments on: '. $topic;

	if ( $in->{cancel} ) { # Send them back to the comments.
		return( $site->_relocate( $r, 
							"$$site{rootp}/view/$section/$adate/$ident" ) );
	}

	if ( ! ( my @errors = comment_checkvals( $site, $in ) ) && $in->{post} ) {

		if ( $$site{userid} && $$site{force_auth} ) {
			my ($fn, $ln, $em) = (get_pwuid($$site{dbh},$$site{userid}))[3..5];	
			$in->{name} 	= ( $$site{force_auth} > 1 ) ? "$fn $ln" : $fn;
			$in->{email} 	= $em;
		}

		$in->{comment} 	= $site->sanitize_text( $in->{comment} );
		$in->{url} 		= '' if ( ! defined $in->{url} );
		my $approved 	= 0; 					# moderated.
		$approved 		= 1 if ( $opts & 1 );	# unmoderated
		my $post_ip 	= $r->connection->remote_ip;

		# IF unmoderated increment the article comment count.
		if ( $approved ) {
			db_run( $$site{dbh}, 'change comment count',
					sql_update( 'bg_articles', 'WHERE id = '. sql_num( $id ),
								'comment_count' => sql_num( $ccount + 1 ) ) );
		}

		db_run( $$site{dbh}, 'insert new article',
				sql_insert( 'bg_article_comments',
							'bg_article_id'	=> sql_num( $id ),
							'parent_id' 	=> sql_num( 0 ),
							'user_id' 		=> sql_num( $$site{userid} ),
							'approved' 		=> sql_num( $approved ),
							'created' 		=> sql_num( 'now' ),
							'post_ip'		=> sql_str( $post_ip ),
							'name' 			=> sql_str( $in->{name} ), 
							'email' 		=> sql_str( $in->{email} ), 
							'url' 			=> sql_str( $in->{url} ), 
							'content'		=> sql_str( $in->{comment} ) ) );
		
		db_commit( $$site{dbh} );

		# Update their cookie.
		if ( $in->{cookie} ) {
			appbase_cookie_set( $r, $$site{cookie_name}, 
								join( "~|~", 	$in->{name}, $in->{email},
												$in->{url} ), 
								$$site{cookie_expire}, $$site{cookie_path} );
		}

		# Send them back to the comments.
		return( $site->_relocate( $r, 
						"$$site{rootp}/view/$section/$adate/$ident" ) );
	}
	else {
		if ( $r->method eq 'POST' ) {
			return( @errors, comment_form( $site, $in, 1 ) );
		}
		else {
			return( comment_form( $site, $in, 1 ) );
		}
	}
} # END $site->do_add

#-------------------------------------------------
# $site->do_main( $r)
#-------------------------------------------------
sub do_main {
	my ( $site, $r ) = @_;

	$$site{page_title} .= 'Recent Comments';

	my @lines = ( q!<h1>Recent Comments</h1>! );

	my $count = 0;

	my $sth = db_query( $$site{dbh}, 'get comments', 
						'SELECT id, bg_article_id, approved, ',
						'date_part( \'epoch\', created), name, ',
						'url, content FROM bg_article_comments',
						'WHERE approved > 0 ORDER BY created DESC' );

	while( my ( $id, $article_id, $apr, $cdate, $cname, $curl, 
				$ctext ) = db_next( $sth ) ) {

		last if ( $count >= $$site{most_recent} );

		$count++;
		$cname 		= ht_a( $curl, $cname ) if ( is_text( $curl ) );
		my $class 	= ( $apr - 1 ) ? 'owner_comment' : 'comment' ;
					# Works because approved must be 1 or greater.

		my $ath = db_query( $$site{dbh}, 'get article',
							'SELECT bg_section_id, ident, topic, ',
							'date_part( \'epoch\', pub_date ) ',
							'FROM bg_articles WHERE id = ',
							sql_num( $article_id ) );

		my ( $sid, $aident, $atopic, $adate ) = db_next( $ath );

		db_finish( $ath );

		my $bth = db_query( $$site{dbh}, 'get section ident', 
							'SELECT ident FROM bg_sections WHERE id = ',
							sql_num( $sid ) );

		my ( $sident ) = db_next( $bth );

		db_finish( $bth );

		$adate = strftime( "%Y-%m-%d", localtime( $adate ) );
	
		push( @lines, 	ht_div( { 'class' => $class } ),
							qq!<h1>$cname says</h1>!,
							ht_div( { 'class' => 'commentbody' }, $ctext ),
							ht_div( { 'class' => 'commenttime' }, 
									'Posted to ',
									ht_a( 	"$$site{root_blog}/article".
											"/$sident/$adate/$aident", 
											$atopic ), ' on ', 
									strftime( 	$$site{fmt_dt}, 
												localtime($cdate) ) ),	
						ht_udiv() );
	}

	if ( db_rowcount( $sth ) < 1 ) {
		push( @lines, 	ht_div( { 'class' => 'comment' },  
								ht_div( { 'class' => 'commentbody' }, 
										'No Comments' ) ) );
	}

	db_finish( $sth );
	
	return( @lines );
} # END $site->do_main

#-------------------------------------------------
# $site->do_view( $r, $section, $article_date, $ident )
#-------------------------------------------------
sub do_view {
	my ( $site, $r, $section, $adate, $ident ) = @_;

	return( $site->_decline() ) if ( ! is_text( $section ) );
	return( $site->_decline() ) if ( ! is_text( $adate ) );
	return( $site->_decline() ) if ( ! is_text( $ident ) );

	# Verify the section
	my ( $sid, $sname, $sframe ) = ( $site->section_info( $section ) )[0,3,4];
	
	return( $site->_decline() ) if ( ! is_number( $sid ) );

	# Verify the ident and the date.
	my ( $year, $month, $day ) = split( '-', $adate );

	return( $site->_decline() ) if ( ! is_date( "$month-$day-$year" ) );

	my $sth = db_query( $$site{dbh}, 'get article',
						'SELECT bg_articles.id, a_options, ',
						'topic, date_part( \'epoch\', pub_date ) ',
						'FROM bg_articles, bg_article_type WHERE ',
						'bg_article_type.id = bg_article_type_id ',
						'AND published =\'t\' AND pub_date BETWEEN ',
						sql_str( "$year-$month-$day 00:00:00" ), ' AND ', 
						sql_str( "$year-$month-$day 23:59:59" ),
						'AND pub_date <= \'now\'', 
						'AND bg_articles.ident = ', sql_str( $ident ),
						'AND bg_section_id = ', sql_num( $sid ) );

	my ( $id, $opts, $topic, $pub_date ) = db_next( $sth );

	db_finish( $sth );

	return( $site->_decline() ) if ( ! is_number( $id ) );

	return( $site->_decline() ) if ( ! ( $opts & 1 || $opts & 2 ) );

	$$site{page_title} .= 'Comments on: '. $topic;

	my @lines = ( 	q!<h1>Comments on !,
					ht_a( "$$site{root_blog}/article/$section/$adate/$ident",
							$topic ),
					q!</h1>! );

	# Get all of the comments.
	my $ath = db_query( $$site{dbh}, 'get comments', 
						'SELECT approved, date_part( \'epoch\', created), ',
						'name, url, content FROM bg_article_comments ',
						'WHERE bg_article_id = ', sql_num( $id ), 
						' AND approved > 0 ORDER BY created ASC' );
	
	while( my ( $apr, $cdate, $cname, $curl, $ctext ) = db_next( $ath ) ) {

		$cname 		= ht_a( $curl, $cname ) if ( is_text( $curl ) );
		my $class 	= ( $apr - 1 ) ? 'owner_comment' : 'comment' ;
					# Works because approved must be 1 or greater.
	
		push( @lines, 	ht_div( { 'class' => $class } ),
							qq!<h1>$cname says:</h1>!,
							ht_div( { 'class' => 'commentbody' }, $ctext ),
							ht_div( { 'class' => 'commenttime' }, 'Posted on ', 
									strftime( 	$$site{fmt_dt}, 
												localtime($cdate) ) ),	
						ht_udiv() );

	}

	if ( db_rowcount( $ath ) < 1 ) {
		push( @lines, 	ht_div( { 'class' => 'comment' },  
								ht_div( { 'class' => 'commentbody' }, 
										'No Comments' ) ) );
	}

	db_finish( $ath );

	if ( ( $$site{post_time} > 0 ) && 
		 ( time() > $pub_date + ( $$site{post_time} * 86400 ) ) ) {

		# Comments are closed.
		return( @lines, '<p>Comments are closed</p>' );
	}

	# This is so we post to the add page rather than back here.
	my $in 				= $site->param( Apache2::Request->new( $r ) );

	$$site{uri} = "$$site{rootp}/add/$section/$adate/$ident";

	my $cookie 		= appbase_cookie_retrieve( $r );
	if ( is_text( $$cookie{ $$site{cookie_name} } ) ) {
		my $c_text = $$cookie{ $$site{cookie_name} };
		( $in->{name}, $in->{email}, $in->{url} ) = split( /~\|~/, $c_text );
	}

	# FIXME: Fill the name/email/url from cookie/auth
	if ( $$site{userid} ) {
		my ( $fn, $ln, $em ) = (get_pwuid($$site{dbh},$$site{userid}))[3..5];	
		$in->{name} 	= ( $$site{force_auth} > 1 ) ? "$fn $ln" : $fn;
		$in->{email} 	= $em;
	}
	
	$in->{cookie} = 1;

	return( @lines, comment_form( $site, $in ) );
} # END $site->do_view

# EOF
1;

__END__

=head1 NAME 

Alchemy::Blog::Viewer::Comments - Public blog syndication

=head1 SYNOPSIS

  use Alchemy::Blog::Viewer::Comments;

=head1 DESCRIPTION

This module allows the viewing and posting of comments.

=head1 APACHE

This is a sample of the location required for this module to run.
Consult Alchemy::Blog(3) to learn about the configuration options.

  <Location / >
    SetHandler  perl-script

    PerlHandler Alchemy::Blog::Viewer::Comments
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
