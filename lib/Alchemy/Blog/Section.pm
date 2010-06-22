package Alchemy::Blog::Section;
######################################################################
# $Id: Section.pm,v 1.15 2005/09/02 14:05:29 nstudt Exp $
# $Date: 2005/09/02 14:05:29 $
######################################################################
use strict;

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
# $site->do_add( $r )
#-------------------------------------------------
sub do_add {
	my ( $site, $r ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title}	.= 'Add';

	return( $site->_relocate( $r, $$site{rootp} ) ) if ( $in->{cancel} );

	if ( ! ( my @errors = section_checkvals( $site, $in ) ) ) {

		my $options = 0;
		$options |= 1 if ( $in->{opt_title} ); 	# Display title
		$options |= 2 if ( $in->{opt_desc} ); 	# Display description
		$options |= 4 if ( $in->{opt_display} ); 	# display article
		$options |= 8 if ( $in->{opt_order} ); 	# display order

		db_run( $$site{dbh}, 'insert new category',
				sql_insert( 'bg_sections',
							'ident' 		=> sql_str( $in->{ident} ), 
							'name' 			=> sql_str( $in->{name} ),
							'frame'			=> sql_str( $in->{frame} ),
							'article_limit' => sql_num( $in->{alimit} ),
							's_options'		=> sql_num( $options ),
							'language' 		=> sql_str( $in->{language} ),
							'description'	=> sql_str( $in->{descript} ) ) );
		
		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		$in->{alimit} = 0 		if ( ! defined $in->{alimit} );
		$in->{frame} = 'auto' 	if ( ! defined $in->{frame} );

		if ( $r->method eq 'POST' ) {
			return( @errors, section_form( $site, $in ) );
		}
		else {
			return( section_form( $site, $in ) );
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
	return( $site->_relocate( $r, $$site{rootp} ) ) if ( $in->{cancel} );

	my $ath = db_query( $$site{dbh}, 'see if used',
						'SELECT count(id) FROM bg_categories ',
						'WHERE bg_section_id = ', sql_num( $id ) );
	 
	my ( $count ) = db_next( $ath );

	db_finish( $ath );

	# Look to see if used in articles.
	my $bth = db_query( $$site{dbh}, 'see if used', 
						'SELECT count(id) FROM bg_articles ',
						'WHERE bg_section_id = ', sql_num( $id ) );
	
	my ( $acount ) = db_next( $bth );

	db_finish( $bth );

	if ( $count || $acount ) {
		return( ht_div( { 'class' => 'box' } ),
				ht_table( {} ),
				ht_tr(),
					ht_td( 	{ 'class' => 'dta' }, 
							q!Unable to delete this section is in use.! ),
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
				'DELETE FROM bg_sections WHERE id = ', sql_num( $id ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get role information',
							'SELECT name FROM bg_sections WHERE id = ',
							sql_num( $id ) );

		my ( $name ) = db_next( $sth );

		db_finish( $sth );

		return( ht_form_js( "$$site{uri}/yes" ), 
				ht_div( { 'class' => 'box' } ),
				ht_table( {} ),
				ht_tr(),
					ht_td( 	{ 'class' => 'dta' }, 
							qq!Delete the section "$name"?! ),
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
	$$site{page_title}	.= 'Edit';

	return( 'Invalid id.' ) 						if ( ! is_number( $id ) );
	return( $site->_relocate( $r, $$site{rootp} ) ) if ( $in->{cancel} );

	if ( ! ( my @errors = section_checkvals( $site, $in, $id ) ) ) {

		my $options = 0;
		$options |= 1 if ( $in->{opt_title} ); 		# Display title
		$options |= 2 if ( $in->{opt_desc} ); 		# Display description
		$options |= 4 if ( $in->{opt_display} ); 	# display article
		$options |= 8 if ( $in->{opt_order} ); 		# display article

		db_run( $$site{dbh}, 'insert new category',
				sql_update( 'bg_sections', 'WHERE id = '. sql_num( $id ),
							'ident' 		=> sql_str( $in->{ident} ), 
							'name' 			=> sql_str( $in->{name} ),
							'frame'			=> sql_str( $in->{frame} ),
							'article_limit' => sql_num( $in->{alimit} ),
							's_options'		=> sql_num( $options ),
							'language' 		=> sql_str( $in->{language} ),
							'description'	=> sql_str( $in->{descript} ) ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get old values',
							'SELECT ident, name, frame, article_limit, ',
							's_options, language, ',
							'description FROM bg_sections WHERE id = ',
							sql_num( $id ) );

		while ( my( $ident, $name, $frame, $alimit, $opts, $lang,
					$desc ) = db_next( $sth ) ) {

			$in->{oident}	= $ident;
			$in->{ident}	= $ident 	if ( ! defined $in->{ident} );
			$in->{alimit} 	= $alimit 	if ( ! defined $in->{alimit} );
			$in->{frame} 	= $frame 	if ( ! defined $in->{frame} );
			$in->{name} 	= $name 	if ( ! defined $in->{name} );
			$in->{language} = $lang 	if ( ! defined $in->{language} );
			$in->{descript} = $desc 	if ( ! defined $in->{descript} );

			if ( ! defined $in->{opt_title} ) {
				$in->{opt_title} = ( $opts & 1 ) ? 1 : 0 ;
			}
			
			if ( ! defined $in->{opt_desc} ) {
				$in->{opt_desc} = ( $opts & 2 ) ? 1 : 0;
			}

			if ( ! defined $in->{opt_display} ) {
				$in->{opt_display} = ( $opts & 4 ) ? 1 : 0 ;
			}

			if ( ! defined $in->{opt_order} ) {
				$in->{opt_order} = ( $opts & 8 ) ? 1 : 0 ;
			}
		}

		db_finish( $sth );

		if ( $r->method eq 'POST' ) {
			return( @errors, section_form( $site, $in ) );
		}
		else {
			return( section_form( $site, $in ) );
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
					ht_td( 	{ 'class' => 'shd' }, 'Name' ),
					ht_td( 	{ 'class' => 'shd' }, 'Ident' ),
					ht_td( 	{ 'class' => 'rshd' }, '[',
							ht_a( "$$site{rootp}/add", 'Add' ), ']' ),
					ht_utr() );

	my $sth = db_query( $$site{dbh}, 'get sections',
						'SELECT id, ident, name FROM ',
						'bg_sections ORDER BY name' );
	
	while ( my ( $id, $ident, $name ) = db_next( $sth ) ) {

		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'dta' }, $name ), 
						ht_td( 	{ 'class' => 'dta' }, $ident ), 
						ht_td( 	{ 'class' => 'rdta' }, '[', 
								ht_a( 	"$$site{root_category}/main/$id",
										'Categories' ), '|',
								ht_a( 	"$$site{rootp}/edit/$id", 'Edit' ), '|',
								ht_a( 	"$$site{rootp}/delete/$id", 
										'Delete' ), ']' ),
						ht_utr() );
	}

	if ( db_rowcount( $sth ) < 1 ) { 
		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'cdta', 'colspan' => '3' }, 
								'No sections found.' ),
						ht_utr() );

	}

	db_finish( $sth );

	return( @lines, ht_utable(), ht_udiv() );
} # END $site->do_main

#-------------------------------------------------
# section_checkvals( $site, $in, $id )
#-------------------------------------------------
sub section_checkvals {
	my ( $site, $in, $id ) = @_;

	my @errors = ();

	$id = 0 if ( ! is_integer( $id ) );

	if ( ! is_text( $in->{name} ) ) {
		push( @errors, 'Enter a name for this section.'. ht_br() );
	}

	if ( ! is_integer( $in->{alimit} ) ) {
		push( @errors, 'Enter a numeric article limit.'. ht_br() );
	}

	if ( ! is_ident( $in->{ident} ) ) {
		push( @errors, 'Enter an ident for this author.'. ht_br() );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'see if used',
							'SELECT count(id) FROM bg_sections ',
							'WHERE ident = ', sql_str( $in->{ident} ) );

		my ( $count ) = db_next( $sth );

		db_finish( $sth );

		if ( $id ) {
			if ( $count && $in->{oident} ne $in->{ident} ) {
				push( @errors, 'Ident already in use.'. ht_br() );
			}
		}
		else {
			if ( $count ) {
				push( @errors, 'Ident already in use.'. ht_br() );
			}
		}

	}
	
	return( @errors );
} # END section_checkvals

#-------------------------------------------------
# section_form( $site, $in )
#-------------------------------------------------
sub section_form {
	my ( $site, $in ) = @_;

	return( ht_form_js( $$site{uri} ),	
			ht_div( { 'class' => 'box' } ),
			ht_table( {} ),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Name', 
					ht_help( $$site{help}, 'item', 'a:bg:s:name' ) ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'name', 'text', $in, 'size="30"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Ident',
					ht_help( $$site{help}, 'item', 'a:bg:s:ident' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'oident', 'hidden', $in ),
					ht_input( 'ident', 'text', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Frame', 
					ht_help( $$site{help}, 'item', 'a:bg:s:frame' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'frame', 'text', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Article Limit', 
					ht_help( $$site{help}, 'item', 'a:bg:s:alimit' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'alimit', 'text', $in, 'size="10"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Display Title',
					ht_help( $$site{help}, 'item', 'a:bg:s:opt_title' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'opt_title', 1, $in, '', '',
								'0', 'No', '1', 'Yes' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Display Description',
					ht_help( $$site{help}, 'item', 'a:bg:s:opt_desc' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'opt_desc', 1, $in, '', '',
								'0', 'No', '1', 'Yes' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Sort Articles',
					ht_help( $$site{help}, 'item', 'a:bg:s:opt_order' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'opt_order', 1, $in, '', '', 
								'0', 'Newest First', '1', 'Oldest First' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Display Articles',
					ht_help( $$site{help}, 'item', 'a:bg:s:opt_display' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'opt_display', 1, $in, '', '', 
								'0', 'Summary', '1', 'Full Article' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Language',
					ht_help( $$site{help}, 'item', 'a:bg:s:language' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'language', 'text', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Description',
					ht_help( $$site{help}, 'item', 'a:bg:s:descript' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 	'descript', 'textarea', $in, 
								'cols="50" rows="5"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Save' ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END section_form

# EOF
1;

__END__

=head1 NAME 

Alchemy::Blog::Section - Section mangement.

=head1 SYNOPSIS

  use Alchemy::Blog::Section;

=head1 DESCRIPTION

Sections are the top level distintion in this application, each section
has the ability to aggregate its categories to a front page. A section
also allows for RSS feeds.

=head1 APACHE

This is a sample of the location required for this module to run.
Consult Alchemy::Blog(3) to learn about the configuration options.

  <Location /admin/section >
    SetHandler  perl-script

    PerlHandler Alchemy::Blog::Section
  </Location>

=head1 DATABASE

This is the only table that this module manipulates.

  create table "bg_sections" (
    id              int4 PRIMARY KEY DEFAULT NEXTVAL( 'bg_sections_seq' ),
    ident           varchar,
    name            varchar,
	frame			varchar,
    article_limit   int2, /* max articles to view at once, 0 for no limit */
    s_options       int4, /* boolean options for blog */
    language        varchar,
    description     text
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
