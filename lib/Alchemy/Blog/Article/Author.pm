package Alchemy::Blog::Article::Author;
######################################################################
# $Id: Author.pm,v 1.11 2005/09/02 14:05:29 nstudt Exp $
# $Date: 2005/09/02 14:05:29 $
######################################################################
use strict;
use Apache2::Request;
use Apache2::Upload;
use APR::Const -compile => qw(:common);

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
# author_checkvals( $site, $in, $id )
#-------------------------------------------------
sub author_checkvals {
	my ( $site, $in, $id ) = @_;

	my @errors;

	$id = 0 if ( ! is_integer( $id ) );

	if ( ! is_text( $in->{name} ) ) {
		push( @errors, 'Enter a name for this author.'. ht_br() );
	}

	if ( ! is_email( $in->{email} ) ) {
		push( @errors, 'Enter an e-mail address for this author.'.  ht_br() );
	}

	if ( ! is_ident( $in->{ident} ) ) {
		push( @errors, 'Enter an ident for this author.'. ht_br() );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'see if used',
							'SELECT count(id) FROM bg_authors ',
							'WHERE ident = ', sql_str( $in->{ident} ) );

		my ( $count ) = db_next( $sth );

		db_finish( $sth );

		if ( $id && $in->{oident} ne $in->{ident} ) {
			push( @errors, 'Ident already in use.'. ht_br() );
		}

		if ( ! $id && $count ) {
			push( @errors, 'Ident already in use.'. ht_br() );
		}
	}

	return( @errors );
} # END author_checkvals( $in )

#-------------------------------------------------
# author_form( $site, $in )
#-------------------------------------------------
sub author_form {
	my ( $site, $in ) = @_;

	return( ht_form_js( $$site{uri} ),	
			ht_div( { 'class' => 'box' } ),
			ht_table( {} ),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Name',
					ht_help( $$site{help}, 'item', 'a:bg:aa:name' ) ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'name', 'text', $in, 'size="30"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'E-mail',
					ht_help( $$site{help}, 'item', 'a:bg:aa:email' ) ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'email', 'text', $in, 'size="30"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Ident',
					ht_help( $$site{help}, 'item', 'a:bg:aa:name' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'oident', 'hidden', $in ),
					ht_input( 'ident', 'text', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Bio',
					ht_help( $$site{help}, 'item', 'a:bg:aa:bio' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 	'bio', 'textarea', $in, 
								'cols="40" rows="10"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Save' ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END author_form

#-------------------------------------------------
# $site->do_add( $r )
#-------------------------------------------------
sub do_add {
	my ( $site, $r ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title}	.= 'Add';
	
	return( $site->_relocate( $r, $$site{rootp} ) ) if ( $in->{cancel} );

	if ( ! ( my @errors = author_checkvals( $site, $in ) ) ) {

		$in->{bio} =~ s/(\r\n)|\r/\n/g;

		db_run( $$site{dbh}, 'insert new author',
				sql_insert( 'bg_authors',
							'ident' 	=> sql_str( $in->{ident} ), 
							'name' 		=> sql_str( $in->{name} ), 
							'email' 	=> sql_str( $in->{email} ), 
							'bio'		=> sql_str( $in->{bio} ) ) );
		
		my $id = db_lastseq( $$site{dbh}, 'bg_authors_seq' );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/view/$id" ) );
	}
	else {
		if ( $r->method eq 'POST' ) {
			return( @errors, author_form( $site, $in ) );
		}
		else {
			return( author_form( $site, $in ) );
		}
	}
} # END $site->do_add

#-------------------------------------------------
# $site->do_delete( $r, $id, $yes )
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, $id, $yes ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Delete';

	return( 'Invalid id.' ) 						if ( ! is_integer( $id ) );

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, $$site{rootp} ) );
	}

	my $ath = db_query( $$site{dbh}, 'see if used',
						'SELECT count(id) FROM bg_articles ',
						'WHERE bg_author_id = ', sql_num( $id ) );
	 
	my ( $count ) = db_next( $ath );

	db_finish( $ath );

	if ( $count ) {
		return( ht_div( { 'class' => 'box' } ),
				ht_table( {} ),
				ht_tr(),
					ht_td( 	{ 'class' => 'dta' }, 
							q!Unable to delete, still in use.! ),
				ht_utr(),
				ht_tr(),
					ht_td( { 'class' => 'rshd' }, 
							ht_a( $$site{rootp}, 'Back to Listing' ) ),
				ht_utr(),
				ht_utable(),
				ht_udiv() );
	}

	if ( ( defined $yes ) && ( $yes eq 'yes' ) ) {

		my $sth = db_query( $$site{dbh}, 'get photo',
							'SELECT photo FROM bg_authors WHERE id = ',
							sql_num( $id ) );

		my ( $photo ) = db_next( $sth );

		db_finish( $sth );

		if ( is_text( $photo ) ) {
			unlink( "$$site{file_path}/$photo" ) 
				or die "Can't remove photo: $!";
		}

		db_run( $$site{dbh}, 'remove the role',
				'DELETE FROM bg_authors WHERE id = ', sql_num( $id ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		# Look up the role information.
		my $sth = db_query( $$site{dbh}, 'get role information',
							'SELECT name FROM bg_authors WHERE id = ',
							sql_num( $id ) );

		my ( $name ) = db_next( $sth );

		db_finish( $sth );

		return( ht_form_js( "$$site{uri}/yes" ), 
				ht_div( { 'class' => 'box' } ),
				ht_table( {} ),
				ht_tr(),
					ht_td( 	{ 'class' => 'dta' }, 
							qq!Delete the author "$name"?! ),
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
# $site->do_edit( $r, $id )
#-------------------------------------------------
sub do_edit {
	my ( $site, $r, $id ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title}	.= 'Update';

	return( 'Invalid id.' ) if ( ! is_integer( $id ) );

	if ( $in->{cancel} ) {
		return( $site->_relocate( $r, $$site{rootp} ) );
	}

	if ( ! ( my @errors = author_checkvals( $site, $in, $id ) ) ) {

		$in->{bio} =~ s/(\r\n)|\r/\n/g;

		db_run( $$site{dbh}, 'insert new author',
				sql_update( 'bg_authors', 'WHERE id = '. sql_num( $id ),
							'ident' 	=> sql_str( $in->{ident} ), 
							'name' 		=> sql_str( $in->{name} ), 
							'email' 	=> sql_str( $in->{email} ), 
							'bio'		=> sql_str( $in->{bio} ) ) );

		db_commit( $$site{dbh} );

		# Send to the photo page. ? or the view ?
		return( $site->_relocate( $r, "$$site{rootp}/view/$id" ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get old values',
							'SELECT ident, name, email, bio ',
							'FROM bg_authors WHERE id = ', sql_num( $id ) );

		while ( my ( $ident, $name, $email, $bio ) = db_next( $sth ) ) {
			$in->{oident} 	= $ident;
			$in->{ident}	= $ident 	if ( ! defined $in->{ident} );
			$in->{name} 	= $name 	if ( ! defined $in->{name} );
			$in->{email}	= $email 	if ( ! defined $in->{email} );
			$in->{bio} 		= $bio 		if ( ! defined $in->{bio} );
		}

		db_finish( $sth );

		if ( $r->method eq 'POST' ) {
			return( @errors, author_form( $site, $in ) );
		}
		else {
			return( author_form( $site, $in ) );
		}
	}
} # END $site->do_edit

#-------------------------------------------------
# $site->do_main( $r )
#-------------------------------------------------
sub do_main {
	my ( $site, $r ) = @_;

	$$site{page_title} .= 'Listing';

	my @lines = ( 	ht_div( { 'class' => 'box' } ),
					ht_table(),

					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, 'Author' ),
					ht_td( 	{ 'class' => 'shd' }, 'Ident' ),
					ht_td( 	{ 'class' => 'rshd' }, 
							'[', ht_a( "$$site{rootp}/add", 'Add' ), '|',
							 ht_a( $$site{root_article}, 'Articles' ), ']', ),
					ht_utr() );

	my $sth = db_query( $$site{dbh}, 'list all authors',
						'SELECT id, ident, name FROM bg_authors ',
						'ORDER BY name' );
	
	while ( my ( $id, $ident, $name ) = db_next( $sth ) ) {

		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'dta' }, 
								ht_a( "$$site{rootp}/view/$id", $name ) ),
						ht_td( 	{ 'class' => 'dta' }, $ident ),
						ht_td( 	{ 'class' => 'rdta' }, 
								'[', 
								ht_a( "$$site{rootp}/edit/$id", 'Edit' ),  '|',
								ht_a( "$$site{rootp}/delete/$id", 'Delete' ),
								']' ),
						ht_utr() );
	}

	if ( db_rowcount( $sth ) < 1 ) {
		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'cdta', 'colspan' => '3' }, 
								'No authors found.' ),
						ht_utr() );
	}

	db_finish( $sth );

	return( @lines, ht_utable(), ht_udiv() );
} # END $site->do_main

#-------------------------------------------------
# $site->do_photo( $r, $id )
#-------------------------------------------------
sub do_photo {
	my ( $site, $r, $id ) = @_;

	$$site{page_title}	.= 'Photo';

	return( 'Invalid id.' ) if ( ! is_integer( $id ) );

	my $apr    	= Apache2::Request->new( $r, TEMP_DIR => $$site{file_tmp} );
#                                            POST_MAX => 1023450 );
    #my $status  = $apr->body_status;
	#my $in = $apr->param;
	my $in = $site->param( $apr );
    
	#return( 'Error: Upload File too large.' ) if ( $status );

	if ( $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/view/$id" ) );
	}

	my $sth = db_query( $$site{dbh}, 'get old values',
						'SELECT photo FROM bg_authors WHERE id = ',
						sql_num( $id ) );

	while ( my ( $photo ) = db_next( $sth ) ) {
		$in->{photo} = $photo 	if ( ! defined $in->{photo} );
	}

	db_finish( $sth );

	warn( 'A4' );
	if ( ! ( my @errors = photo_checkvals( $in, $apr ) ) ) {

		my $upload 			= $apr->upload( 'newfile' );
		my $type 			= $upload->type();
		$type 				=~ s/\//_/g;
		my ( $t, $fname )   = $upload->filename =~ /^(.*\\|.*\/)?(.*?)?$/;

		# Attach_path/$now-$uname-$type-$fname
		my $file = "$$site{file_path}/author_$id\_$fname";
		
		if ( open( ATTACH, ">$file" ) ) {

			my $fh = $upload->fh;

			while ( my $part = <$fh> ) {
				print ATTACH $part;
			}

			close( ATTACH );
		}
		else {
			die "Could not open $file: $!";
		}

		# Remove the old photo.
		if ( is_text( $in->{photo} ) ) {
			unlink( "$$site{file_path}/$in->{photo}" );
		}

		db_run( $$site{dbh}, 'insert new author',
				sql_update( 'bg_authors', 'WHERE id = '. sql_num( $id ),
							'photo' 	=> sql_str( "author_$id\_$fname" ) ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/view/$id" ) );
	}
	else {
		if ( $r->method eq 'POST' ) {
			return( @errors, photo_form( $site, $in ) );
		}
		else {
			return( photo_form( $site, $in ) );
		}
	}
} # END $site->do_photo

#-------------------------------------------------
# $site->do_users( $r, $id )
#-------------------------------------------------
sub do_users {
	my ( $site, $r, $id ) = @_;

	return( 'Edit author users.' );
} # END $site->do_users

#-------------------------------------------------
# $site->do_view( $r, $id )
#-------------------------------------------------
sub do_view {
	my ( $site, $r, $id ) = @_;

	$$site{page_title} = 'Detail';

	return( 'Invalid id.' ) if ( ! is_integer( $id ) );

	my $sth = db_query( $$site{dbh}, 'look up the info',
						'SELECT ident, name, email, photo, bio',
						'FROM bg_authors WHERE id = ', sql_num( $id ) );
	
	my ( $ident, $name, $email, $photo, $bio ) = db_next( $sth );
	
	db_finish( $sth );

	my $image = '';
	my @photos;
	
	if ( $photo ) {
		$image = ht_img( "$$site{file_uri}/$photo", qq!alt="$name"! );
		push( @photos, ht_a( "$$site{rootp}/photo/$id", 'Update Photo' ), '|' );
	}
	else {
		push( @photos, ht_a( "$$site{rootp}/photo/$id", 'Add Photo' ), '|' );
	}


	return( '<h1>Preview</h1>',
			ht_div(),
			'[', ht_a( $$site{rootp}, 'Main' ), '|', @photos,
			ht_a( "$$site{rootp}/edit/$id", 'Edit' ), '|',
			ht_a( "$$site{rootp}/delete/$id", 'Delete'), ']',
			ht_udiv(),

			ht_div( { 'class' => 'author' } ),
			ht_div( { 'class' => 'author_header' } ),
			'<h1>', $name, '</h1>',
			'<h2>', $email, '</h2>',
			ht_udiv(),
			ht_div( { 'class' => 'author_content' } ),
			$image,
			$bio,
			ht_udiv(),
			ht_udiv() );
} # END $site->do_view

#-------------------------------------------------
# photo_checkvals( $in, $apr )
#-------------------------------------------------
sub photo_checkvals {
	my ( $in, $apr ) = @_;

	my @errors;

	if ( ! is_text( $in->{newfile} ) ) {
		push( @errors, 'Select a file to upload.'. ht_br() );
	}
	else { # Check the file size.
		my $upload 	= $apr->upload( 'newfile' );
		my $size 	= $upload->size;

		if ( ! defined $size || $size < 1 ) {
			push( @errors, 'Select a file to upload.'. ht_br() );
		}
	}

	return( @errors );
} # END photo_checkvals

#-------------------------------------------------
# photo_form( $site, $in )
#-------------------------------------------------
sub photo_form {
	my ( $site, $in ) = @_;

	my $photo = ($in->{photo}) ? ht_img( "$$site{file_uri}/$in->{photo}" ):
								'No photo';

	return( ht_form_js( $$site{uri}, 'enctype="multipart/form-data"' ),	
			ht_div( { 'class' => 'box' } ),
			ht_table( {} ),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Current', ),
			ht_td( 	{ 'class' => 'dta' }, $photo ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Upload', ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'newfile', 'file', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Save' ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END photo_form

#-------------------------------------------------
# users_checkvals( $in )
#-------------------------------------------------
sub users_checkvals {
	my ( $in ) = @_;

	my @errors = ( 'bad things' );

	return( @errors );
} # END users_checkvals()

#-------------------------------------------------
# users_form( $site, $in )
#-------------------------------------------------
sub users_form {
	my ( $site, $in ) = @_;

	return( 'users form' );
} # END users_form

# EOF
1;

__END__

=head1 NAME 

Alchemy::Blog::Author - Author management.

=head1 SYNOPSIS

  use Alchemy::Blog::Article::Author;

=head1 DESCRIPTION

This module manages authors that may be assigned to articles.

=head1 APACHE

This is a sample of the location required for this module to run.
Consult Alchemy::Blog(3) to learn about the configuration options.

  <Location /admin/authors >
    SetHandler  perl-script

    PerlHandler Alchemy::Blog::Author
  </Location>

=head1 DATABASE

This is the only table this module manipulates.

  create table "bg_authors" (
    id      int4 PRIMARY KEY DEFAULT NEXTVAL( 'bg_authors_seq' ),
    ident   varchar, 
    name    varchar,
    email   varchar,
    photo   varchar,
    bio     text
  );

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
