package Alchemy::Blog::Article;
######################################################################
# $Id: Article.pm,v 1.17 2005/09/02 14:05:29 nstudt Exp $
# $Date: 2005/09/02 14:05:29 $
######################################################################
use strict;
use POSIX qw( strftime );

use KrKit::Calendar;
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
# article_checkvals( $site, $in )
#-------------------------------------------------
sub article_checkvals {
	my ( $site, $in, $id ) = @_;

	my @errors;

	if ( ! is_text( $in->{topic} ) ) {
		push( @errors, 'Enter article topic.'. ht_br() );
	}

	if ( ! is_integer( $in->{section} ) ) {
		push( @errors, 'Select a section.'. ht_br() );
	}

	if ( ! is_integer( $in->{author} ) ) {
		push( @errors, 'Select an author.'. ht_br() );
	}

	if ( is_text( $in->{ident} ) ) {
		if ( is_ident( $in->{ident} ) ) {
			my $sth = db_query( $$site{dbh}, 'see if used',
								'SELECT count(id) FROM bg_articles ',
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
		else {
			push( @errors, 'Enter a valid ident.'. ht_br() );
		}
	}

	if ( ! is_integer( $in->{comment} ) ) {
		push( @errors, 'Select comment status.'. ht_br() );
	}

	if ( ! is_date( $in->{pubdate} ) ) {
		push( @errors, 'Enter publication date.'. ht_br() );
	}

	if ( ! is_time( $in->{pubtime} ) ) {
		push( @errors, 'Enter publication time.'. ht_br() );
	}

	if ( ! is_integer( $in->{type} ) ) {
		push( @errors, 'Select article type.'. ht_br() );
	}

	if ( ! is_text( $in->{summary} ) ) {
		push( @errors, 'Enter article summary.'. ht_br() );
	}

	if ( ! is_text( $in->{article} ) ) {
		push( @errors, 'Enter article content.'. ht_br() );
	}

	return( @errors );
} # END article_checkvals

#-------------------------------------------------
# article_form( $site, $in )
#-------------------------------------------------
sub article_form {
	my ( $site, $in ) = @_;

	my @author 	= ( '', '- Select -' );
	my @type 	= ( '', '- Select -' );
	my @section	= ( '', '- Select -' );

	my $sth = db_query( $$site{dbh}, 'get authors list',
						'SELECT id, name FROM bg_authors ORDER BY name' );
	
	while ( my ( $id, $name ) = db_next( $sth ) ) {
		push( @author, $id, $name );
	}

	db_finish( $sth );

	my $ath = db_query( $$site{dbh}, 'get types', 
						'SELECT id, name, published FROM bg_article_type',
						'ORDER BY name' );
	
	while ( my ( $id, $name, $pub ) = db_next( $ath ) ) {
		$pub = $pub ? '( Published )' : '';
		push( @type, $id, "$name $pub" );
	}

	db_finish( $ath );

	my $bth = db_query( $$site{dbh}, 'get sections',
						'SELECT id, name FROM bg_sections ORDER BY name' );

	while ( my ( $id, $name ) = db_next( $bth ) ) {
		push( @section, $id, $name );
	}

	db_finish( $bth );
	
	return( ht_form_js( $$site{uri}, 'name="article"' ),	
			q!<script type="text/javascript">!,
			q!  function SetDate(field, date) { !,
			q!  eval( 'document.article.' + field + '.value = date;' );!,
			q!  } !, 
			
			q!  function datepopup(name) { !,
			qq!     window.open('$$site{rootp}/cal/'+name, !,
			q!                  'Shortcut', 'height=250,width=250' + !,
			q!                  ',screenX=' + (window.screenX+150) + !,
			q!                  ',screenY=' + (window.screenY+100) + !,
			q!                  ',scrollbars,resizable' ); !,
			q!  } !,
			q!</script>!,

			ht_div( { 'class' => 'box' } ),
			ht_table( {} ),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Topic',
					ht_help( $$site{help}, 'item', 'a:bg:a:topic' ) ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'topic', 'text', $in, 'size="40"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Section',
					ht_help( $$site{help}, 'item', 'a:bg:a:section' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'osection', 'hidden', $in ),
					ht_select( 'section', 1, $in, '', '', @section ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Author',
					ht_help( $$site{help}, 'item', 'a:bg:a:author' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 'author', 1, $in, '', '', @author ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Ident',
					ht_help( $$site{help}, 'item', 'a:bg:a:ident' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'oident', 'hidden', $in ),
					ht_input( 'ident', 'text', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Comments',
					ht_help( $$site{help}, 'item', 'a:bg:a:comment' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'comment', 1, $in, '', '', 
								'1','Yes', '2','Yes, Moderated', '0','No' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Publication Date/Time',
					ht_help( $$site{help}, 'item', 'a:bg:a:pubdate' ) ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'pubdate', 'text', $in, 'size="10"' ),
					'[', ht_a( 'javascript://', 'Set Date', 
							q!onClick="datepopup('pubdate')"! ), ']',
					ht_input( 'pubtime', 'text', $in, 'size="6"' ), 'hrs.' ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Type',
					ht_help( $$site{help}, 'item', 'a:bg:a:type' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 'type', 1, $in, '', '', @type ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Summary',
					ht_help( $$site{help}, 'item', 'a:bg:a:summary' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 	'summary', 'textarea', $in, 
								'cols="50" rows="3"' ) ),
			ht_utr(),


			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Article',
					ht_help( $$site{help}, 'item', 'a:bg:a:article' ) ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 	'article', 'textarea', $in, 
								'cols="50" rows="10"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Save' ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END article_form

#-------------------------------------------------
# calendar_day( $year, $month, $day )
#-------------------------------------------------
sub calendar_day {          
	my ( $year, $month, $day ) = @_; 

	return( ht_a(   'javascript://', "$day",
					"onClick=\"SendDate('$month-$day-$year')\"" ) );
} # END calendar_day

#-------------------------------------------------
# category_checkvals( $in )
#-------------------------------------------------
sub category_checkvals {
	my $in = shift;

	my @errors;

	if ( ! is_text( $in->{all_cats} ) ) {
		push( @errors, 'unknown error.' );
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
			ht_td( { 'class' => 'shd' }, 'Topic', ),
			ht_td( { 'class' => 'dta' }, $in->{topic} ),
			ht_utr(),

			ht_tr(),
			ht_td( { 'class' => 'shd' }, 'Categories', ),
			ht_td( { 'class' => 'dta' }, category_tree( $site, $in, 0 ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_input( 'all_cats', 'hidden', $in ),
					ht_submit( 'submit', 'Save' ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END category_form

#-------------------------------------------------
# category_tree( $site, $in, $parent_id )
#-------------------------------------------------
sub category_tree {
	my ( $site, $in, $pid ) = @_;

	return() if ( ! is_number( $pid ) );

	my @lines;

	my $sth = db_query( $$site{dbh}, 'get categories',
						'SELECT id, name FROM bg_categories WHERE ',
						'parent_id = ', sql_num( $pid ), 
						'AND bg_section_id = ', sql_num( $in->{section} ),
						'ORDER BY name' );

	while ( my ( $id, $name ) = db_next( $sth ) ) {
		push( @lines, 	'<li>', 
							ht_checkbox( "cat_$id", 1, $in ), $name,
							category_tree( $site, $in, $id ), 
						'</li>' );
	}

	db_finish( $sth );

	return( '<ul>', @lines, '</ul>' ) if ( @lines );

	return();
} # END category_tree

#-------------------------------------------------
# $site->do_add( $r )
#-------------------------------------------------
sub do_add {
	my ( $site, $r ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title}	.= 'Add';
	
	return( $site->_relocate( $r, $$site{rootp} ) ) if ( $in->{cancel} );

	if ( ! ( my @errors = article_checkvals( $site, $in ) ) ) {

		$in->{article} 	=~ s/(\r\n)|\r/\n/g;
		my $date 		= "$in->{pubdate} $in->{pubtime}";
		my $options		= 0;
		$options 		|= 1 if ( $in->{comment} eq "1" );
		$options 		|= 2 if ( $in->{comment} eq "2" );

		my $ident 		= '';

		if ( is_text( $in->{ident} ) ) {
			$ident = $in->{ident};
		}
		else {
			$ident = $site->generate_ident($in->{topic}, $$site{ident_length});
		}

		db_run( $$site{dbh}, 'insert new article',
				sql_insert( 'bg_articles',
							'bg_article_type_id'=> sql_num( $in->{type} ),
							'bg_author_id' 		=> sql_num( $in->{author} ),
							'bg_section_id' 	=> sql_num( $in->{section} ),
							'comment_count' 	=> sql_num( '0' ),
							'a_options'	 		=> sql_num( $in->{comment} ),
							'ident' 			=> sql_str( $ident ), 
							'topic' 			=> sql_str( $in->{topic} ), 
							'pub_date' 			=> sql_str( $date ), 
							'modified' 			=> sql_str( 'now' ), 
							'summary'			=> sql_str( $in->{summary} ),
							'content'		=> sql_str( $in->{article} ) ) );
		
		my $id = db_lastseq( $$site{dbh}, 'bg_articles_seq' );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/category/$id" ) );
	}
	else {
		
		# Set the publication date and time
		if ( ! defined $in->{pubdate} ) {
			$in->{pubdate} = strftime( "%m-%d-%Y", localtime() );
		}

		if ( ! defined $in->{pubtime} ) {
			$in->{pubtime} = strftime( "%H:%M", localtime() );
		}

		# Set the author if we know who we are.
		if ( $r->method eq 'POST' ) {
			return( @errors, article_form( $site, $in ) );
		}
		else {
			return( article_form( $site, $in ) );
		}
	}
} # END $site->do_add

#-------------------------------------------------
# $site->do_cal( $r, $name, $year, $month )
#-------------------------------------------------
sub do_cal {
	my ( $site, $r, $name, $year, $month ) = @_;

	$$site{frame} 		= 'plain';
	$$site{page_title} 	= 'Calendar Popup';

	$name	= '' 							if ( ! is_text( $name ) );
	$year	= ( 1900 + ( localtime() )[5] ) if ( ! is_number( $year ) );
	$month	= ( 1 + ( localtime() )[4] ) 	if ( ! is_number( $month ) );;

	return( '<script type="text/javascript">',
            '<!--',
            '   function SendDate(d) { ',
            qq!     window.opener.SetDate("$name",d); window.close(); !,
            '   } ',
            '//--> ',
            '</script>',
			cal_month( 	$r, "$$site{rootp}/cal/$name", $month,
						$year, 1, \&calendar_day ) ); 
} # END $site->do_cal

#-------------------------------------------------
# $site->do_category( $r, $id )
#-------------------------------------------------
sub do_category {
	my ( $site, $r, $id ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} .= 'Categories';

	return( 'Invalid id.' ) 						if ( ! is_integer( $id ) );
	return( $site->_relocate( $r, $$site{rootp} ) ) if ( $in->{cancel} );

	if ( ! ( my @errors = category_checkvals( $in ) ) ) {

		# Delete all categories.
		db_run( $$site{dbh}, 'remove old categories',
				'DELETE FROM bg_article_categories WHERE ',
				'bg_article_id = ', sql_num( $id ) );

		for my $cid ( split( /:/, $in->{all_cats} ) ) {

			next if ( ! defined $in->{"cat_$cid"} );

			db_run( $$site{dbh}, 'insert into category',
					sql_insert( 'bg_article_categories',
								'bg_category_id'	=> sql_num( $cid ),
								'bg_article_id'		=> sql_num( $id ) ) );
		}

		# Set the modified on the article.
		db_run( $$site{dbh}, 'update article modified',
				sql_update( 'bg_articles', 'WHERE id ='. sql_num( $id ),
							'modified' => sql_str( 'now' ) ) );
		
		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/preview/$id" ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get topic', 
							'SELECT bg_section_id, topic FROM bg_articles',
							'WHERE id = ', sql_num( $id ) );

		( $in->{section}, $in->{topic} ) = db_next( $sth );

		db_finish( $sth );
		
		# Look up the old categories we are in.
		my $ath = db_query( $$site{dbh}, 'get categories',
							'SELECT bg_category_id FROM ',
							'bg_article_categories WHERE bg_article_id = ',
							sql_num( $id )  );

		while ( my ( $cid ) = db_next( $ath ) ) {
			$in->{"cat_$cid"} = 1;
		}

		db_finish( $ath );

		my @cats;
	
		my $bth = db_query( $$site{dbh}, 'get all categories',
							'SELECT id FROM bg_categories' );

		while ( my ( $cid ) = db_next( $bth ) ) {
			push( @cats, $cid );
		}

		db_finish( $bth );

		$in->{all_cats} = join( ':', @cats );

		if ( $r->method eq 'POST' ) {
			return( @errors, category_form( $site, $in ) );
		}
		else {
			return( category_form( $site, $in ) );
		}
	}
} # END $site->do_category

#-------------------------------------------------
# $site->do_delete( $r, $id, $yes )
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, $id, $yes ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Delete';

	return( 'Invalid id.' ) if ( ! is_integer( $id ) );

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, $$site{rootp} ) );
	}

	if ( ( defined $yes ) && ( $yes eq 'yes' ) ) {

		db_run( $$site{dbh}, 'remove the article',
				'DELETE FROM bg_article_categories WHERE bg_article_id = ',
				sql_num( $id ) );

		db_run( $$site{dbh}, 'remove comments',
				'DELETE FROM bg_article_comments WHERE bg_article_id = ',
				sql_num( $id ) );

		db_run( $$site{dbh}, 'remove the article',
				'DELETE FROM bg_articles WHERE id = ', sql_num( $id ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		# Look up the role information.
		my $sth = db_query( $$site{dbh}, 'get role information',
							'SELECT topic FROM bg_articles WHERE id = ',
							sql_num( $id ) );

		my ( $name ) = db_next( $sth );

		db_finish( $sth );

		return( ht_form_js( "$$site{uri}/yes" ), 
				ht_div( { 'class' => 'box' } ),
				ht_table( {} ),
				ht_tr(),
					ht_td( 	{ 'class' => 'dta' }, 
							qq!Delete the article "$name"?! ),
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
	
	return( 'Invalid id.' ) 						if ( ! is_integer( $id ) );
	return( $site->_relocate( $r, $$site{rootp} ) ) if ( $in->{cancel} );

	if ( ! ( my @errors = article_checkvals( $site, $in, $id ) ) ) {

		my $ident 		= '';
		$in->{article} 	=~ s/(\r\n)|\r/\n/g;
		my $date 		= "$in->{pubdate} $in->{pubtime}";

		my $options		= 0;
		$options 		|= 1 if ( $in->{comment} eq "1" );
		$options 		|= 2 if ( $in->{comment} eq "2" );

		if ( is_text( $in->{ident} ) ) {
			$ident = $in->{ident};
		}
		else {
			$ident = $site->generate_ident( $in->{topic},
											$$site->{ident_length} );
		}

		db_run( $$site{dbh}, 'insert new article',
				sql_update( 'bg_articles', 'WHERE id = '. sql_num( $id ),
							'bg_section_id' 	=> sql_num( $in->{section} ),
							'bg_article_type_id'=> sql_num( $in->{type} ),
							'bg_author_id' 		=> sql_num( $in->{author} ),
							'a_options'	 		=> sql_num( $in->{comment} ),
							'ident' 			=> sql_str( $in->{ident} ), 
							'topic' 			=> sql_str( $in->{topic} ), 
							'pub_date' 			=> sql_str( $date ), 
							'modified' 			=> sql_str( 'now' ), 
							'summary'			=> sql_str( $in->{summary} ),
							'content'			=> sql_str($in->{article}) ) );

		if ( $in->{section} ne $in->{osection} ) {
			# Remove the old sections.
			db_run( $$site{dbh}, 'remove old categories',
					'DELETE FROM bg_article_categories WHERE ',
					'bg_article_id = ', sql_num( $id ) );
		}
		
		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/preview/$id" ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get old values',
							'SELECT bg_section_id, bg_article_type_id, ',
							'bg_author_id, a_options, ident, topic, ',
							'date_part( \'epoch\', pub_date ), summary, ',
							'content FROM bg_articles WHERE id = ', 
							sql_num( $id ) );

		while ( my( $sid, $type, $author, $options, $ident, $topic, $date,
					$summary, $content ) = db_next( $sth ) ) {
		
			$in->{oident} 	= $ident;
			$in->{osection}	= $sid;
			$in->{ident} 	= $ident 	if ( ! defined $in->{ident} );
			$in->{section} 	= $sid		if ( ! defined $in->{section} );
			$in->{topic} 	= $topic 	if ( ! defined $in->{topic} );
			$in->{author} 	= $author 	if ( ! defined $in->{author} );
			$in->{type} 	= $type 	if ( ! defined $in->{type} );
			$in->{summary} 	= $summary 	if ( ! defined $in->{summary} );
			$in->{article} 	= $content 	if ( ! defined $in->{article} );

			if ( ! defined $in->{comment} ) {
				$in->{comment} = 0;
				$in->{comment} = 1 if ( $options & 1 );
				$in->{comment} = 2 if ( $options & 2 );
			}

			# Set the publication date and time
			if ( ! defined $in->{pubdate} ) {
				$in->{pubdate} = strftime( "%m-%d-%Y", localtime( $date ) );
			}

			if ( ! defined $in->{pubtime} ) {
				$in->{pubtime} = strftime( "%H:%M", localtime( $date ) );
			}
		}

		db_finish( $sth );

		if ( $r->method eq 'POST' ) {
			return( @errors, article_form( $site, $in ) );
		}
		else {
			return( article_form( $site, $in ) );
		}
	}
} # END $site->do_edit

#-------------------------------------------------
# $site->do_main( $r )
#-------------------------------------------------
sub do_main {
	my ( $site, $r ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} .= 'Search';

	my ( @lines, $sth );

	if ( ! ( my @errors = search_checkvals( $in ) ) ) {
		# Do the search requested.
		push( @lines, ( ( $r->method eq 'POST' ) ? @errors : '' ) ); 

		my @sql = ( 'bg_article_type_id = bg_article_type.id' );

		if ( is_date( $in->{date} ) ) {
			push( @sql, 'pub_date >= '. sql_str( $in->{date} ) );
		}

		if ( is_text( $in->{topic} ) ) {
			push( @sql, 'topic ~* '. sql_str( $in->{topic} ) );
		}

		if ( is_integer( $in->{type} ) ) {
			push( @sql, 'bg_article_type_id = '. sql_num( $in->{type} ) );
		}

		$sth = db_query( $$site{dbh}, 'get default view',
							'SELECT bg_articles.id, topic, name, ',
							'published FROM bg_articles, bg_article_type ',
							'WHERE ', join( ' AND ', @sql ), 
							'ORDER BY published, pub_date DESC' );
	}
	else {
		if ( ! defined $in->{date} ) {
			$in->{date} = strftime( "%m-%d-%Y", localtime( time - (7*86400) ) );
		}

		push( @lines, ( ( $r->method eq 'POST' ) ? @errors : '' ) ); 
						
		# Do the default search.
		$sth = db_query( $$site{dbh}, 'get default view',
							'SELECT bg_articles.id, topic, name ',
							'FROM bg_articles, bg_article_type ',
							'WHERE bg_article_type_id = bg_article_type.id ',
							'AND ( modified >= ', sql_str( $in->{date} ),
							' OR published = \'f\' ) ORDER BY published, ',
							'pub_date DESC' );
	}

	push( @lines, 	search_form( $site, $in ), 
					ht_div( { 'class' => 'box' } ),
					ht_table(),
					ht_tr(),
					ht_td( 	{ 'class' => 'hdr' }, 'Results' ),
					ht_td( 	{ 'class' => 'rhdr', 'colspan' => '2' }, 
							'[', ht_a( $$site{root_author}, 'Authors' ), '|',
							ht_a( $$site{root_type}, 'Article Types' ), ']' ),
					ht_utr(),

					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, 'Topic' ),
					ht_td( 	{ 'class' => 'shd' }, 'Type' ),
					ht_td( 	{ 'class' => 'rshd' }, 
							'[', ht_a( "$$site{rootp}/add", 'Add' ), ']',),
					ht_utr() );

	while ( my ( $id, $topic, $type ) = db_next( $sth )  ) {

		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'dta' }, 
								ht_a( "$$site{rootp}/preview/$id", $topic ) ),
						ht_td( 	{ 'class' => 'dta' }, $type ),
						ht_td( 	{ 'class' => 'rdta' }, '[',
								ht_a( "$$site{rootp}/edit/$id", 'Edit' ), '|',
								ht_a( "$$site{rootp}/delete/$id", 'Delete' ), 
								']' ),
						ht_utr() );
	}

	if ( db_rowcount( $sth ) < 1 ) {
		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'cdta', 'colspan' => '3' },
								'No matching articles found.' ), 
						ht_utr() );
	}

	db_finish( $sth );

	return( @lines, ht_utable(), ht_udiv() );
} # END $site->do_main

#-------------------------------------------------
# $site->do_preview( $r, $id )
#-------------------------------------------------
sub do_preview {
	my ( $site, $r, $id ) = @_;

	$$site{page_title} .= 'Preview';

	return( 'Invalid id.' ) if ( ! is_integer( $id ) );

	# Look up the article and display it.
	my $sth = db_query( $$site{dbh}, 'get article',
						'SELECT bg_article_type_id, bg_author_id, topic,',
						'date_part( \'epoch\', pub_date ), ',
						'date_part( \'epoch\', modified ), content ',
						'FROM bg_articles WHERE id = ', sql_num( $id ) );

	my ( $tid, $aid, $topic, $pub, $mod, $content ) = db_next( $sth );

	db_finish( $sth );

	my $ath = db_query( $$site{dbh}, 'get author', 
						'SELECT name, ident FROM bg_authors WHERE id = ',
						sql_num( $aid ) );
		
	my ( $author, $aident ) = db_next( $ath );

	db_finish( $ath );

	my @categories;

	my $bth = db_query( $$site{dbh}, 'get categories', 
						'SELECT bg_categories.ident, bg_categories.name, ',
						'bg_sections.ident FROM bg_categories, ',
						'bg_article_categories, bg_sections WHERE ',
						'bg_sections.id = bg_categories.bg_section_id AND ',
						'bg_categories.id = bg_category_id AND ',
						'bg_article_id = ', sql_num( $id )  );

	while ( my ( $cident, $cname, $sident ) = db_next( $bth ) ) {
		push( @categories, ht_a( "$$site{root_blog}/category/$sident/$cident",
									$cname ) );
	}

	db_finish( $bth );

	return( '<h1>Preview</h1>',
			ht_div(),
			'[', ht_a( $$site{rootp}, 'Main' ), '|',
			ht_a( "$$site{rootp}/edit/$id", 'Edit' ), '|',
			ht_a( "$$site{root_comment}/article/$id", 'Comments' ), '|',
			ht_a( "$$site{rootp}/category/$id", 'Categories' ), '|',
			ht_a( "$$site{rootp}/delete/$id", 'Delete' ), ']',
			ht_udiv(),

			ht_div( { 'class' => 'article' } ),
			ht_div( { 'class' => 'article_header' } ),
			'<h1 class="topic">', $topic, '</h1>',
			'<h2 class="date">', 
				strftime( $$site{fmt_dt}, localtime($pub) ),
			'</h2>',
			'<h3 class="author">',
				ht_a( "$$site{root_blog}/author/$aident", $author ),
			'</h3>',
			'<h4 class="category">',
				( ( @categories ) ? 'File Under: ' : '' ),
				( ( @categories ) ? join( ', ', @categories ) : '' ),
			'</h4>',
			ht_udiv(),
			ht_div( { 'class' => 'content' } ),
				$content, 
			ht_udiv(),
			ht_div( { 'class' => 'article_footer' } ),
				'Last modified: ',
				strftime( $$site{fmt_dt}, localtime($mod) ),
			ht_udiv(),
			ht_udiv() );
} # END $site->do_preview

#-------------------------------------------------
# $site->generate_ident( $suggested, $max_length )
#-------------------------------------------------
sub generate_ident {
	my ( $site, $suggested, $max ) = @_;
	
	$suggested = lc( $suggested );
	$suggested =~ s/\s+/_/g;
	$suggested =~ s/\W//g; 
	$suggested = substr( $suggested, 0, $max );

	my $sth = db_query( $$site{dbh}, 'get ident',
						'SELECT id FROM bg_articles WHERE ident = ', 
						sql_str( $suggested ) );
	
	my ( $id ) = db_next( $sth );

	db_finish( $sth );
	
	if ( is_number( $id ) ) {

		my $ath = db_query( $$site{dbh}, 'get ident',
							'SELECT ident FROM bg_articles WHERE ident ~* ',
							sql_str( "^$suggested-" ), 'ORDER BY ident' );

		my $dbcount = db_rowcount( $ath ) + 1;

		db_finish( $ath );

		$suggested = "$suggested-$dbcount";
	}

	return( $suggested );
} # END $site->generate_ident

#-------------------------------------------------
# search_checkvals( $in )
#-------------------------------------------------
sub search_checkvals {
	my $in = shift;

	my $errors = 0;

	$errors += is_text( $in->{topic} );
	$errors += is_integer( $in->{type} );
	$errors += is_date( $in->{date} );

	if ( ! $errors ) {
		return( 'You must enter something to search on.'. ht_br() );
	}

	return();
} # END search_checkvals

#-------------------------------------------------
# search_form( $site, $in ) 
#-------------------------------------------------
sub search_form {
	my ( $site, $in ) = @_;
	
	my @type = ( '', '- Any -' );

	my $ath = db_query( $$site{dbh}, 'get types', 
						'SELECT id, name, published FROM bg_article_type',
						'ORDER BY name' );
	
	while ( my ( $id, $name, $pub ) = db_next( $ath ) ) {
		$pub = $pub ? '( Published )' : '';
		push( @type, $id, "$name $pub" );
	}

	db_finish( $ath );
	
	return( ht_form_js( $$site{uri}, 'name="search"' ),	
			q!<script type="text/javascript">!,
			q!  function SetDate(field, date) { !,
			q!  eval( 'document.search.' + field + '.value = date;' );!,
			q!  } !, 
			
			q!  function datepopup(name) { !,
			qq!     window.open('$$site{rootp}/cal/'+name, !,
			q!                  'Shortcut', 'height=250,width=250' + !,
			q!                  ',screenX=' + (window.screenX+150) + !,
			q!                  ',screenY=' + (window.screenY+100) + !,
			q!                  ',scrollbars,resizable' ); !,
			q!  } !,
			q!</script>!,

			ht_div( { 'class' => 'box' } ),
			ht_table( {} ),

			ht_tr(),
			ht_td( { 'class' => 'hdr', 'colspan' => '2' }, 'Search' ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Topic', ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'topic', 'text', $in, 'size="40"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Type', ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 'type', 1, $in, '', '', @type ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Published Since' ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'date', 'text', $in, 'size="10"' ),
					'[', ht_a( 'javascript://', 'Set Date', 
							q!onClick="datepopup('date')"! ), ']' ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Search' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END search_form

# EOF
1;

__END__

=head1 NAME 

Alchemy::Blog::Article - Blog article management.

=head1 SYNOPSIS

  use Alchemy::Blog::Article;

=head1 DESCRIPTION

This module is the administrative interface for blog articles, this is
the main section of the blog that authors will actually use to post
content.

=head1 APACHE

This is a sample of the location required for this module to run.
Consult Alchemy::Blog(3) to learn about the configuration options.

  <Location /admin/articles >
    SetHandler  perl-script

    PerlHandler Alchemy::Blog::Article
  </Location>

=head1 DATABASE

These are the tables that this module manipulates.

  create table "bg_articles" (
    id                  int4 PRIMARY KEY DEFAULT NEXTVAL( 'bg_articles_seq' ),
    bg_article_type_id  int4,
    bg_author_id        int4,
	bg_section_id		int4,
    comment_count       int4,
    a_options           int4,
    ident               varchar,
    topic               varchar,
    pub_date            timestamp with time zone,
    modified            timestamp with time zone,
    content             text
  );

  create table "bg_article_categories" (
    bg_category_id  int4, 
    bg_article_id   int4
  );

=head1 SEE ALSO

Alchemy::Blog(3), Alchemy(3), KrKit(3)

=head1 LIMITATIONS

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 2003-2004 Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
