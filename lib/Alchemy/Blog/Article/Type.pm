package Alchemy::Blog::Article::Type;
######################################################################
# $Id: Type.pm,v 1.10 2005/09/02 14:05:29 nstudt Exp $
# $Date: 2005/09/02 14:05:29 $
######################################################################
use strict;

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
# $site->do_add( $r )
#-------------------------------------------------
sub do_add {
	my ( $site, $r ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title}	.= 'Add Type';
	
	return( $site->_relocate( $r, $$site{rootp} ) ) if ( $in->{cancel} );

	if ( ! ( my @errors = type_checkvals( $site, $in ) ) ) {

		db_run( $$site{dbh}, 'insert new type',
				sql_insert( 'bg_article_type',
							'published' => sql_bool( $in->{publish} ), 
							'name'		=> sql_str( $in->{name} ) ) );

		db_commit( $$site{dbh} );
	
		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		if ( $r->method eq 'POST' ) {
			return( @errors, type_form( $site, $in ) );
		}
		else {
			return( type_form( $site, $in ) );
		}
	}
} # END $site->do_add

#-------------------------------------------------
# $site->do_delete( $r, $id, $yes )
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, $id, $yes ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Delete Type';

	return( 'Invalid id.' ) if ( ! is_integer( $id ) );

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, $$site{rootp} ) );
	}

	my $ath = db_query( $$site{dbh}, 'see if used',
						'SELECT count(id) FROM bg_articles ',
						'WHERE bg_article_type_id = ', sql_num( $id ) );
	 
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

		db_run( $$site{dbh}, 'remove the role',
				'DELETE FROM bg_article_type WHERE id = ', sql_num( $id ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		# Look up the role information.
		my $sth = db_query( $$site{dbh}, 'get role information',
							'SELECT name FROM bg_article_type WHERE id = ',
							sql_num( $id ) );

		my ( $name ) = db_next( $sth );

		db_finish( $sth );

		return( ht_form_js( "$$site{uri}/yes" ), 
				ht_div( { 'class' => 'box' } ),
				ht_table( {} ),
				ht_tr(),
					ht_td( 	{ 'class' => 'dta' }, 
							qq!Delete the article type "$name"?! ),
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
	$$site{page_title}	.= 'Edit Type';

	return( 'Invalid id' ) if ( ! is_integer( $id ) );

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, $$site{rootp} ) );
	}

	if ( ! ( my @errors = type_checkvals( $site, $in, $id ) ) ) {

		db_run( $$site{dbh}, 'insert new type',
				sql_update( 'bg_article_type', 'WHERE id = '. sql_num( $id ),
							'published' => sql_bool( $in->{publish} ), 
							'name'		=> sql_str( $in->{name} ) ) );

		db_commit( $$site{dbh} );
	
		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get old values',
							'SELECT published, name FROM ',
							'bg_article_type WHERE id = ', sql_num( $id ) );

		while ( my ( $pub, $name ) = db_next( $sth ) ) {
			$in->{publish} 	= $pub 		if ( ! defined $in->{publish} );
			$in->{name} 	= $name 	if ( ! defined $in->{name} );
		}

		db_finish( $sth );

		if ( $r->method eq 'POST' ) {
			return( @errors, type_form( $site, $in ) );
		}
		else {
			return( type_form( $site, $in ) );
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
					ht_table( ),

					ht_tr(),
					ht_td( 	{ 'class' => 'shd' } , 'Name' ),
					ht_td( 	{ 'class' => 'shd' } , 'Publish' ),
					ht_td( 	{ 'class' => 'rshd' } , 
							'[', ht_a( "$$site{rootp}/add", 'Add' ), '|',
							 ht_a( $$site{root_article}, 'Articles' ), ']', ),
					ht_utr() );

	my $sth = db_query( $$site{dbh}, 'get list',
						'SELECT id, published, name FROM ',
						'bg_article_type ORDER BY name' );

	while ( my ( $id, $pub, $name ) = db_next( $sth ) ) {

		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'dta' }, $name ),
						ht_td( 	{ 'class' => 'dta' }, 
								( $pub ? 'Yes' : 'No' ) ),
						ht_td( 	{ 'class' => 'rdta' }, 
								'[',
								ht_a( "$$site{rootp}/edit/$id", 'Edit' ), '|',
								ht_a( "$$site{rootp}/delete/$id", 'Delete' ),
								']' ),
						ht_utr() );
	}

	if ( db_rowcount( $sth ) < 1 ) {
		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'cdta', 'colspan' => '6' }, 
								'No article types found.' ),
						ht_utr() );

	}

	db_finish( $sth );

	return( @lines, ht_utable(), ht_udiv() );
} # END $site->do_main

#-------------------------------------------------
# type_checkvals( $site, $in, $id )
#-------------------------------------------------
sub type_checkvals {
	my ( $site, $in, $id ) = @_;

	my @errors;

	$id = 0 if ( ! is_integer( $id ) );

	if ( ! is_text( $in->{name} ) ) {
		push( @errors, 'Enter a name for this article type.'. ht_br() );
	}

	if ( ! is_integer( $in->{publish} ) ) {
		push( @errors, 'Select published status.'. ht_br() );
	}

	return( @errors );
} # END type_checkvals

#-------------------------------------------------
# type_form( $site, $in )
#-------------------------------------------------
sub type_form {
	my ( $site, $in ) = @_;

	return( ht_form_js( $$site{uri} ),	
			ht_div( { 'class' => 'box' } ),

			ht_table( {} ),
			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Name',
					ht_help( $$site{help}, 'item', 'a:bg:at:name' ) ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'name', 'text', $in, 'size="30"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Publish',
					ht_help( $$site{help}, 'item', 'a:bg:at:publish' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'publish', 1, $in, '', '', 
								'1', 'Yes', '0', 'No' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Save' ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),

			ht_udiv(),
			ht_uform() );
} # END type_form

# EOF
1;

__END__

=head1 NAME 

Alchemy::Blog::Article::Type - Article type management.

=head1 SYNOPSIS

  use Alchemy::Blog::Article::Type;

=head1 DESCRIPTION

This module manages the article types that are used for articles.

=head1 APACHE

This is a sample of the location required for this module to run.
Consult Alchemy::Blog(3) to learn about the configuration options.

  <Location /admin/article_type >
    SetHandler  perl-script

    PerlHandler Alchemy::Blog::Article::Type
  </Location>

=head1 DATABASE

This is the only database table that this module manipulates.

  create table "bg_article_type" (
    id          int4 PRIMARY KEY DEFAULT NEXTVAL( 'bg_article_type_seq' ),
    published   bool, /* if this type is a live article */
    name        varchar
  );

=head1 SEE ALSO

Alchemy::Blog(3), Alchemy(3), KrKit(3)

=head1 LIMITATIONS

=head1 AUTHOR

Nicholas Studt <nstudt@angrydwarf.org>

=head1 COPYRIGHT

Copyright (c) 2003 Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
