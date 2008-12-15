package Alchemy::Blog::Section::Category;
######################################################################
# $Id: Category.pm,v 1.11 2005/09/02 14:05:29 nstudt Exp $
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
# category_checkvals( $site, $in, $id )
#-------------------------------------------------
sub category_checkvals {
	my ( $site, $in, $id ) = @_;

	my @errors;
	
	$id = 0 if ( ! is_integer( $id ) );

	if ( ! is_text( $in->{name} ) ) {
		push( @errors, 'Enter a name for the category.'. ht_br() );
	}

	# frame ?

	if ( ! is_integer( $in->{alimit} ) ) {
		push( @errors, 'Enter a numeric article limit.'. ht_br() );
	}

	if ( ! is_ident( $in->{ident} ) ) {
		push( @errors, 'Enter an ident for this author.'. ht_br() );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'see if used',
							'SELECT count(id) FROM bg_categories ',
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
} # END category_checkvals

#-------------------------------------------------
# category_form( $site, $in )
#-------------------------------------------------
sub category_form {
	my ( $site, $in ) = @_;

	return( ht_form_js( $$site{uri} ),	
			ht_div( { 'class' => 'box' } ),
			ht_table( {} ),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Name',
					ht_help( $$site{help}, 'item', 'a:bg:sc:name' ) ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'name', 'text', $in, 'size="30"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Parent Category', ),
			ht_td( 	{ 'class' => 'dta' }, $in->{parent_name} ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Ident',
					ht_help( $$site{help}, 'item', 'a:bg:sc:ident' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'oident', 'hidden', $in ),
					ht_input( 'ident', 'text', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Frame',
					ht_help( $$site{help}, 'item', 'a:bg:sc:frame' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'frame', 'text', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Article Limit',
					ht_help( $$site{help}, 'item', 'a:bg:sc:alimit' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'alimit', 'text', $in, 'size="10"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Display Title', 
					ht_help( $$site{help}, 'item', 'a:bg:sc:opt_title' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'opt_title', 1, $in, '', '',
								'0', 'No', '1', 'Yes' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Display Sub-categories',
					ht_help( $$site{help}, 'item', 'a:bg:sc:opt_subs' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'opt_subs', 1, $in, '', '', 
								'0', 'No', '1', 'Yes' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Display Description',
					ht_help( $$site{help}, 'item', 'a:bg:sc:opt_desc' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'opt_desc', 1, $in, '', '', 
								'0', 'No', '1', 'Yes' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Sort Articles',
					ht_help( $$site{help}, 'item', 'a:bg:sc:opt_order' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'opt_order', 1, $in, '', '', 
								'0', 'Newest First', '1', 'Oldest First' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Display Articles',
					ht_help( $$site{help}, 'item', 'a:bg:sc:opt_display' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'opt_display', 1, $in, '', '', 
								'0', 'Summary', '1', 'Full Article' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Description',
					ht_help( $$site{help}, 'item', 'a:bg:sc:description' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 	'description', 'textarea', $in, 
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

} # END category_form

#-------------------------------------------------
# $site->do_add( $r, $section_id, $id )
#-------------------------------------------------
sub do_add {
	my ( $site, $r, $sid, $pid ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title}	.= 'Add';

	return( 'Invalid section id.' )	if ( ! is_integer( $sid ) );
	return( 'Invalid parent id.' )	if ( ! is_integer( $pid ) );

	if ( $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/main/$sid/$pid" ) );
	}

	if ( ! ( my @errors = category_checkvals( $site, $in ) ) ) {

		my $options = 0;
		$options |= 1 	if ( $in->{opt_title} ); 	# Display title
		$options |= 2 	if ( $in->{opt_subs} ); 	# Display categories
		$options |= 4 	if ( $in->{opt_display} ); 	# display article
		$options |= 8 	if ( $in->{opt_order} ); 	# display order
		$options |= 16 	if ( $in->{opt_desc} ); 	# display description

		db_run( $$site{dbh}, 'insert new category',
				sql_insert( 'bg_categories',
							'bg_section_id'	=> sql_num( $sid ),
							'parent_id' 	=> sql_num( $pid ),
							'article_limit' => sql_num( $in->{alimit} ),
							'c_options'		=> sql_num( $options ),
							'ident' 		=> sql_str( $in->{ident} ), 
							'frame'			=> sql_str( $in->{frame} ),
							'name' 			=> sql_str( $in->{name} ),
							'description'	=> sql_str( $in->{description} )));
		
		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/main/$sid/$pid" ) );
	}
	else {
		$in->{alimit} = 0 		if ( ! defined $in->{alimit} );
		$in->{frame} = 'auto' 	if ( ! defined $in->{frame} );

		if ( $pid > 0 ) {
			my $sth = db_query( $$site{dbh}, 'get parent name', 
								'SELECT name FROM bg_categories WHERE id = ',
								sql_num( $pid ), ' AND bg_section_id = ',
								sql_num( $sid ) );
		
			( $in->{parent_name} ) = db_next( $sth );
	
			db_finish( $sth );
		}
		else {
			$in->{parent_name} = 'Top Level';
		}

		if ( $r->method eq 'POST' ) {
			return( @errors, category_form( $site, $in ) );
		}
		else {
			return( category_form( $site, $in ) );
		}
	}
} # END $site->do_add

#-------------------------------------------------
# $site->do_delete( $r, $section_id, $parent_id, $id, $yes )
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, $sid, $pid, $id, $yes ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Delete';

	return( 'Invalid section id.' )	if ( ! is_integer( $sid ) );
	return( 'Invalid parent id.' )	if ( ! is_integer( $pid ) );
	return( 'Invalid id.' ) 		if ( ! is_integer( $id ) );

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/main/$sid/$pid" ) );
	}

	my $ath = db_query( $$site{dbh}, 'see if used',
						'SELECT count(id) FROM bg_categories ',
						'WHERE parent_id = ', sql_num( $id ), 
						'AND bg_section_id = ', sql_num( $sid ) );
	 
	my ( $count ) = db_next( $ath );

	db_finish( $ath );

	if ( $count ) {
		return( ht_div( { 'class' => 'box' } ),
				ht_table( {} ),
				ht_tr(),
					ht_td( 	{ 'class' => 'dta' }, 
							q!Unable to delete, this has children.! ),
				ht_utr(),
				ht_tr(),
					ht_td( { 'class' => 'rshd' }, 
							ht_a( $$site{rootp}, 'Back to Listing' ) ),
				ht_utr(),
				ht_utable(),
				ht_udiv() );
	}

	if ( ( defined $yes ) && ( $yes eq 'yes' ) ) {

		db_run( $$site{dbh}, 'remove the stories in this category',
				'DELETE FROM bg_article_categories WHERE bg_category_id = ', 
				sql_num( $id ) );

		db_run( $$site{dbh}, 'remove the role',
				'DELETE FROM bg_categories WHERE id = ', sql_num( $id ), 
				'AND bg_section_id = ', sql_num( $sid ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/main/$sid" ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get role information',
							'SELECT name FROM bg_categories WHERE id = ',
							sql_num( $id ), 'AND bg_section_id = ',
							sql_num( $sid ) );

		my ( $name ) = db_next( $sth );

		db_finish( $sth );

		return( ht_form_js( "$$site{uri}/yes" ), 
				ht_div( { 'class' => 'box' } ),
				ht_table( {} ),
				ht_tr(),
					ht_td( 	{ 'class' => 'dta' }, 
							qq!Delete the category "$name"? Stories in !,
							q!this category will be orphaned! ),
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
# $site->do_edit( $r, $section_id, $parent_id, $id )
#-------------------------------------------------
sub do_edit {
	my ( $site, $r, $sid, $pid, $id ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title}	.= 'Update';

	return( 'Invalid section id.' )	if ( ! is_integer( $sid ) );
	return( 'Invalid parent id.' )	if ( ! is_integer( $pid ) );
	return( 'Invalid id.' )			if ( ! is_integer( $id ) );

	if ( $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/main/$sid/$pid" ) );
	}

	if ( ! ( my @errors = category_checkvals( $site, $in, $id ) ) ) {

		my $options = 0;
		$options |= 1 	if ( $in->{opt_title} ); 	# Display title
		$options |= 2 	if ( $in->{opt_subs} ); 	# Display categories
		$options |= 4 	if ( $in->{opt_display} ); 	# display article
		$options |= 8 	if ( $in->{opt_order} ); 	# display order
		$options |= 16 	if ( $in->{opt_desc} ); 	# display description

		db_run( $$site{dbh}, 'insert new category',
				sql_update( 'bg_categories', 'WHERE id = '. sql_num( $id ),
							'article_limit' => sql_num( $in->{alimit} ),
							'c_options'		=> sql_num( $options ),
							'ident' 		=> sql_str( $in->{ident} ), 
							'frame'			=> sql_str( $in->{frame} ),
							'name' 			=> sql_str( $in->{name} ),
							'description'	=> sql_str( $in->{description} )));
		
		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/main/$sid/$pid" ) );
	}
	else {
		if ( $pid > 0 ) {
			my $sth = db_query( $$site{dbh}, 'get parent name', 
								'SELECT name FROM bg_categories WHERE id = ',
								sql_num( $pid ), 'AND bg_section_id = ', 
								sql_num( $sid ) );
		
			( $in->{parent_name} ) = db_next( $sth );
	
			db_finish( $sth );
		}
		else {
			$in->{parent_name} = 'Top Level';
		}

		my $ath = db_query( $$site{dbh}, 'get old values', 
							'SELECT article_limit, c_options, ident, frame,',
							'name, description FROM bg_categories WHERE id =', 
							sql_num( $id ), 'AND bg_section_id = ',
							sql_num( $sid ) );

		while ( my( $alim, $opts, $ident, $frame, $name, 
					$desc ) = db_next( $ath ) ) {

			$in->{oident}		= $ident;
			$in->{ident} 		= $ident 	if ( ! defined $in->{ident} );
			$in->{alimit} 		= $alim 	if ( ! defined $in->{alimit} );
			$in->{frame} 		= $frame 	if ( ! defined $in->{frame} );
			$in->{name} 		= $name 	if ( ! defined $in->{name} );
			$in->{description} 	= $desc 	if ( ! defined $in->{description} );

			if ( ! defined $in->{opt_title} ) {
				$in->{opt_title} = ( $opts & 1 ) ? 1 : 0 ;
			}

			if ( ! defined $in->{opt_subs} ) {
				$in->{opt_subs} = ( $opts & 2 ) ? 1 : 0 ;
			}

			if ( ! defined $in->{opt_display} ) {
				$in->{opt_display} = ( $opts & 4 ) ? 1 : 0 ;
			}

			if ( ! defined $in->{opt_order} ) {
				$in->{opt_order} = ( $opts & 8 ) ? 1 : 0 ;
			}

			if ( ! defined $in->{opt_desc} ) {
				$in->{opt_desc} = ( $opts & 16 ) ? 1 : 0 ;
			}
		}

		db_finish( $ath );

		if ( $r->method eq 'POST' ) {
			return( @errors, category_form( $site, $in ) );
		}
		else {
			return( category_form( $site, $in ) );
		}
	}
} # END $site->do_edit

#-------------------------------------------------
# $site->do_main( $r, $section_id, $parent_id )
#-------------------------------------------------
sub do_main {
	my ( $site, $r, $sid, $pid ) = @_;

	$$site{page_title} = 'Listing';

	return( 'Invalid id.' ) if ( ! is_number( $sid ) );

	my ( $link, $p_name ) = ( '', 'Top of Category Tree' );

	$pid = 0 if ( ! is_integer( $pid ) );

	if ( $pid > 0 ) {
		my $ath = db_query( $$site{dbh}, 'get parent info',
							'SELECT name, parent_id FROM bg_categories ',
							'WHERE id = ', sql_num( $pid ),
							'AND bg_section_id = ', sql_num( $sid ) );

		my ( $pname, $parent ) = db_next( $ath );

		$p_name = $pname;
		$link =	ht_a( "$$site{rootp}/main/$sid/$parent", 'Up a level' ). ' |';

		db_finish( $ath );
	}

	my $bth = db_query( $$site{dbh}, 'get section info', 
						'SELECT name FROM bg_sections WHERE id = ',
						sql_num( $sid ) );
	
	my ( $section ) = db_next( $bth );

	db_finish( $bth );

	my @lines = ( 	ht_div( { 'class' => 'box' } ),
					ht_table(),

					ht_tr(),
					ht_td( 	{ 'class' => 'hdr', 'colspan' => 2 }, 
							$section, '&mdash;', $p_name ),
					ht_td( 	{ 'class' => 'rhdr' }, 
							'[', $link, 
							ht_a( $$site{root_section}, 'Sections' ), ']' ),
					ht_utr(),

					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, 'Name' ),
					ht_td( 	{ 'class' => 'shd' }, 'Ident' ),
					ht_td( 	{ 'class' => 'rshd' }, '[',
							ht_a( "$$site{rootp}/add/$sid/$pid", 'Add' ), ']' ),
					ht_utr() );

	my $sth = db_query( $$site{dbh}, 'get list', 
						'SELECT id, ident, name FROM bg_categories ',
						'WHERE parent_id = ', sql_num( $pid ), 
						'AND bg_section_id = ', sql_num( $sid ),
						'ORDER BY name' );

	while ( my ( $id, $ident, $name ) = db_next( $sth ) ) {

		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'dta' }, 
								ht_a( "$$site{rootp}/main/$sid/$id", $name ) ), 
						ht_td( 	{ 'class' => 'dta' }, $ident ), 
						ht_td( 	{ 'class' => 'rdta' }, '[', 
								ht_a( 	"$$site{rootp}/edit/$sid/$pid/$id", 
										'Edit' ), '|',
								ht_a( 	"$$site{rootp}/delete/$sid/$pid/$id", 
										'Delete' ), ']' ),
						ht_utr() );
	}

	if ( db_rowcount( $sth ) < 1 ) {
		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'cdta', 'colspan' => '3' }, 
								'No categories found.' ),
						ht_utr() );
	}

	db_finish( $sth );

	return( @lines, ht_utable(), ht_udiv() );
} # END $site->do_main

# EOF
1;

__END__

=head1 NAME 

Alchemy::Blog::Category - Category mangement.

=head1 SYNOPSIS

  use Alchemy::Blog::Category;

=head1 DESCRIPTION

This module manages categories for the system.

=head1 APACHE

This is a sample of the location required for this module to run.
Consult Alchemy::Blog(3) to learn about the configuration options.

  <Location /admin/category >
    SetHandler  perl-script

    PerlHandler Alchemy::Blog::Category
  </Location>

=head1 DATABASE

This is the only table that this module manipulates.

  create table "bg_categories" (
    id              int4 PRIMARY KEY DEFAULT NEXTVAL( 'bg_categories_seq' ),
	bg_section_id	int4,
    parent_id       int4, /* the parent category, 0 for toplevel */
    article_limit   int2, /* max articles to view at once, 0 for no limit */
    comments        bool, /* can this category have comments ? */
    moderated       bool, /* Are the comments moderated ? */
    ident           varchar,
    frame           varchar,
    name            varchar
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
