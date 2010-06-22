package Alchemy::Blog::Article::Comments;
######################################################################
# $Id: Comments.pm,v 1.19 2005/09/02 14:05:29 nstudt Exp $
# $Date: 2005/09/02 14:05:29 $
######################################################################
use strict;
use Apache2::Connection;
use POSIX qw( strftime );

use KrKit::AppBase;
use KrKit::Control;
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
					ht_submit( 'submit', 'Preview comment' ), 
					@button ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );

} # END comment_form

#-------------------------------------------------
# $site->do_add( $r, $article_id ) 
#-------------------------------------------------
sub do_add {
	my ( $site, $r, $article_id ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title}	.= 'Comment Preview';

	return( 'Invalid id.' ) if ( ! is_number( $article_id ) );

	my $sth = db_query( $$site{dbh}, 'get article',
						'SELECT a_options, topic, comment_count ',
						'FROM bg_articles WHERE id = ',
						sql_num( $article_id ) );

	my ( $opts, $topic, $ccount  ) = db_next( $sth );

	db_finish( $sth );

	if ( ! ( $opts & 1 || $opts & 2 ) ) {
		return( 'Comments not allowed on this article.' );
	}

	$$site{page_title} .= 'Comments on: '. $topic;

	if ( $in->{cancel} ) { # Send them back to the comments.
		return( $site->_relocate( $r, "$$site{rootp}/article/$article_id" ) );
	}

	if ( ! ( my @errors = comment_checkvals( $site, $in ) ) && $in->{post} ) {

		if ( $$site{userid} && $$site{force_auth} ) {
			my ($fn, $ln, $em) = (get_pwuid($$site{dbh},$$site{userid}))[3..5];	
			$in->{name} 	= ( $$site{force_auth} > 1 ) ? "$fn $ln" : $fn;
			$in->{email} 	= $em;
		}

		$in->{comment} 	= $site->sanitize_text( $in->{comment} );
		$in->{url} 		= '' if ( ! defined $in->{url} );
		my $post_ip 	= $r->connection->remote_ip;

		# Increment the article comment count.
		db_run( $$site{dbh}, 'change comment count',
				sql_update( 'bg_articles', 'WHERE id ='. sql_num( $article_id ),
							'comment_count' => sql_num( $ccount + 1 ) ) );


		db_run( $$site{dbh}, 'insert new article',
				sql_insert( 'bg_article_comments',
							'bg_article_id'	=> sql_num( $article_id ),
							'parent_id' 	=> sql_num( 0 ),
							'user_id' 		=> sql_num( $$site{userid} ),
							'approved' 		=> sql_num( 2 ),
							'created' 		=> sql_num( 'now' ),
							'post_ip'		=> sql_str( $post_ip ),
							'name' 			=> sql_str( $in->{name} ), 
							'email' 		=> sql_str( $in->{email} ), 
							'url' 			=> sql_str( $in->{url} ), 
							'content'		=> sql_str( $in->{comment} ) ) );
		
		db_commit( $$site{dbh} );

		# Update their cookie, if they want it.
		if ( $in->{cookie} ) {
			appbase_cookie_set( $r, $$site{cookie_name}, 
								join( "~|~", 	$in->{name}, $in->{email},
												$in->{url} ), 
								$$site{cookie_expire}, $$site{cookie_path} );
		}

		# Send them back to the comments.
		return( $site->_relocate( $r, "$$site{rootp}/article/$article_id" ) );
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
# $site->do_approve( $r, $article_id, $id  )
#-------------------------------------------------
sub do_approve {
	my ( $site, $r, $article_id, $id ) = @_;

	$$site{page_title} .= 'Approve Comment';
	
	return( 'Invalid article id.' ) if ( ! is_number( $article_id ) );
	return( 'Invalid id.' ) 		if ( ! is_number( $id ) );

	# Incremint the article comment count.
	my $ath = db_query( $$site{dbh}, 'get old count',
						'SELECT comment_count FROM bg_articles ',
						'WHERE id = ', sql_num( $article_id ) );

	my ( $ccount ) = db_next( $ath );

	db_finish( $ath );

	db_run( $$site{dbh}, 'change comment count',
			sql_update( 'bg_articles', 'WHERE id = '. sql_num( $article_id ),
						'comment_count' => sql_num( $ccount + 1 ) ) );

	# Approve a particulare comment then return to it's view.
	db_run( $$site{dbh}, 'update comment',
			sql_update( 'bg_article_comments', 'WHERE id ='. sql_num( $id ),
						'approved' => sql_num( 1 ) ) );

	db_commit( $$site{dbh} );
	
	return( $site->_relocate( $r, "$$site{rootp}/article/$article_id" ) );
} # END $site->do_approve

#-------------------------------------------------
# $site->do_article( $r, $article_id )
#-------------------------------------------------
sub do_article {
	my ( $site, $r, $article_id ) = @_;

	return( 'Invalid id.' ) if ( ! is_number( $article_id ) );

	my $sth = db_query( $$site{dbh}, 'get article',
						'SELECT a_options, topic FROM bg_articles ',
						'WHERE id = ', sql_num( $article_id ) );

	my ( $opts, $topic ) = db_next( $sth );

	db_finish( $sth );
	
	$$site{page_title} .= 'Comments on: '. $topic;

	if ( ! ( $opts & 1 || $opts & 2 ) ) {
		return( 'Comments not on for this article.' );
	}

	my @lines = ( ht_div(),
					'[', ht_a( $$site{rootp}, 'Main' ), '|',
					ht_a( 	"$$site{root_article}/edit/$article_id",
							'Edit' ), '|',
					ht_a( 	"$$site{root_article}/preview/$article_id", 
							'Preview' ), '|',
					ht_a( 	"$$site{root_article}/category/$article_id", 
							'Categories' ), '|',
					ht_a( 	"$$site{root_article}/delete/$article_id",
							'Delete' ), ']',
					ht_udiv() );

	# Get all of the comments.
	my $ath = db_query( $$site{dbh}, 'get comments', 
						'SELECT id, approved, date_part( \'epoch\', created),',
						'name, email, url, content, post_ip ',
						'FROM bg_article_comments WHERE bg_article_id = ',
						sql_num( $article_id ), 'ORDER BY created ASC' );
	
	while( my ( $id, $apr, $cdate, $cname, $cemail, $curl, 
				$ctext, $postip ) = db_next( $ath ) ) {

		$cname = ht_a( $curl, $cname ) if ( is_text( $curl ) );
		my $class = ( $apr > 1 ) ? 'owner_comment' : 'comment' ;
		my $approve = '';
		if ( $apr < 1 ) {
			$approve = ht_a( 	"$$site{rootp}/approve/$article_id/$id",
								'Approve Comment' ). ' | ';
		}
	
		push( @lines, 	ht_div( { 'class' => $class } ),
							qq!<h1>$cname (!.
								ht_a( "mailto:$cemail", $cemail ).
								q!) says:</h1>!,
							ht_div( { 'class' => 'commentbody' }, $ctext ),
							ht_div( { 'class' => 'commenttime' }, 'Posted on ', 
									strftime( 	$$site{fmt_dt}, 
												localtime($cdate) ),
									'from: ', $postip ),	
							ht_div( { 'class' => 'commentedit' } ),
								$approve,
								ht_a( 	"$$site{rootp}/delete/$article_id/$id",
										'Delete' ),
							ht_udiv(),
						ht_udiv() );

	}

	if ( db_rowcount( $ath ) < 1 ) {
		push( @lines, 	ht_div( { 'class' => 'comment' },  
								ht_div( { 'class' => 'commentbody' }, 
										'No Comments' ) ) );
	}

	db_finish( $ath );

	# This is so we post to the add page rather than back here.
	my $in 		= $site->param( Apache2::Request->new( $r ) );
	$$site{uri}	= "$$site{rootp}/add/$article_id";

	# Fill the name/email/url from cookie
	my $cookie 		= appbase_cookie_retrieve( $r );
	if ( is_text( $$cookie{ $$site{cookie_name} } ) ) {
		my $c_text = $$cookie{ $$site{cookie_name} };
		( $in->{name}, $in->{email}, $in->{url} ) = split( /~\|~/, $c_text );
	}

	if ( $$site{userid} ) {
		my ( $fn, $ln, $em ) = (get_pwuid($$site{dbh},$$site{userid}))[3..5];	
		$in->{name} 	= ( $$site{force_auth} > 1 ) ? "$fn $ln" : $fn;
		$in->{email} 	= $em;
	}

	$in->{cookie} = 1;

	return( @lines, comment_form( $site, $in ) );
} # END $site->do_article

#-------------------------------------------------
# $site->do_delete( $r, $article_id, $id, $yes ) 
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, $article_id, $id, $yes ) = @_;

	# Delete a comment from the database.
	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Delete';

	return( 'Invalid id.' ) if ( ! is_integer( $article_id ) );
	return( 'Invalid id.' ) if ( ! is_integer( $id ) );

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/article/$article_id" ) );
	}

	if ( ( defined $yes ) && ( $yes eq 'yes' ) ) {

		my $sth = db_query( $$site{dbh}, 'get approval',
							'SELECT approved FROM bg_article_comments ',
							'WHERE id = ', sql_num( $id ) );

		my ( $approved ) = db_next( $sth );

		db_finish( $sth );

		if ( $approved ) {
			my $ath = db_query( $$site{dbh}, 'get old count',
								'SELECT comment_count FROM bg_articles ',
								'WHERE id = ', sql_num( $article_id ) );

			my ( $ccount ) = db_next( $ath );

			db_finish( $ath );

			db_run( $$site{dbh}, 'change comment count',
					sql_update( 'bg_articles', 
									'WHERE id='. sql_num( $article_id ),
								'comment_count' => sql_num( $ccount - 1 ) ) );
		}

		db_run( $$site{dbh}, 'remove the article',
				'DELETE FROM bg_article_comments WHERE id =', sql_num( $id ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/article/$article_id" ) );
	}
	else {
		# Look up the role information.
		my $sth = db_query( $$site{dbh}, 'get role information',
							'SELECT name FROM bg_article_comments WHERE id = ',
							sql_num( $id ) );

		my ( $name ) = db_next( $sth );

		db_finish( $sth );

		return( ht_form_js( "$$site{uri}/yes" ), 
				ht_div( { 'class' => 'box' } ),
				ht_table( {} ),
				ht_tr(),
					ht_td( 	{ 'class' => 'dta' }, 
							qq!Delete the comment by "$name"?! ),
				ht_utr(),
				ht_tr(),
					ht_td( { 'class' => 'rshd' }, 
							ht_submit( 'submit', 'Continue with Delete' ),
							ht_submit( 'cancel', 'Cancel' ) ),
				ht_utr(),
				ht_utable(),
				ht_udiv(),
				ht_uform() );
	}
} # END $site->do_delete

#-------------------------------------------------
# $site->do_main( $r )
#-------------------------------------------------
sub do_main {
	my ( $site, $r ) = @_;

	$$site{page_title} .= 'Unapproved comments';

	my @lines = ( q!<h1>Unapproved Comments</h1>! );

	my $ath = db_query( $$site{dbh}, 'get comments', 
						'SELECT id, bg_article_id, approved, ',
						'date_part( \'epoch\', created), name, email, ',
						'url, content, post_ip FROM bg_article_comments',
						'WHERE approved < 1 ORDER BY created ASC' );
	
	while( my ( $id, $article_id, $apr, $cdate, $cname, $email, $curl, 
				$ctext, $postip ) = db_next( $ath ) ) {

		$cname = ht_a( $curl, $cname ) if ( is_text( $curl ) );
	
		push( @lines, 	ht_div( { 'class' => 'comment' } ),
							qq!<h1>$cname (!.  
								ht_a( "mailto:$email", $email ). 
								q!) says:</h1>!,
							ht_div( { 'class' => 'commentbody' }, $ctext ),
							ht_div( { 'class' => 'commenttime' }, 'Posted on ', 
									strftime( 	$$site{fmt_dt}, 
												localtime($cdate) ),
									'from: ', $postip ),	
							ht_div( { 'class' => 'commentedit' } ),
								ht_a( 	"$$site{rootp}/article/$article_id/$id",
										'View in Context' ), ' | ',

								ht_a( 	"$$site{rootp}/approve/$article_id/$id",
										'Approve Comment' ), ' | ',
								ht_a( 	"$$site{rootp}/delete/$article_id/$id",
										'Delete' ),
							ht_udiv(),
						ht_udiv() );
	}

	if ( db_rowcount( $ath ) < 1 ) {
		push( @lines, 	ht_div( { 'class' => 'comment' },  
								ht_div( { 'class' => 'commentbody' }, 
										'No Comments' ) ) );
	}

	db_finish( $ath );
	
	return( @lines );
} # END $site->do_main

# EOF
1;

__END__

=head1 NAME 

Alchemy::Blog::Article::Comments - Comment management.

=head1 SYNOPSIS

  use Alchemy::Blog::Article::Comments;

=head1 DESCRIPTION

This module allows the administrators of a blog to view all comments
manage them when neccessary. 

=head1 APACHE

This is a sample of the location required for this module to run.
Consult Alchemy::Blog(3) to learn about the configuration options.

  <Location /admin/article/comments >
    SetHandler  perl-script
	
    PerlHandler Alchemy::Blog::Article::Comments
  </Location>

=head1 DATABASE

=head1 SEE ALSO

Alchemy::Blog(3), Alchemy(3), KrKit(3)

=head1 LIMITATIONS

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 2003 Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
