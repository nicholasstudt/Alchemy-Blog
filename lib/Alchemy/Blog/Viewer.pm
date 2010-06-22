package Alchemy::Blog::Viewer;
######################################################################
# $Id: Viewer.pm,v 1.32 2005/09/02 14:05:29 nstudt Exp $
# $Date: 2005/09/02 14:05:29 $
######################################################################
use strict;

use Date::Calc qw( Add_Delta_Days Days_in_Month  );
use POSIX qw( strftime );

use KrKit::DB;
use KrKit::Handler;
use KrKit::HTML qw( :all );
use KrKit::SQL;
use KrKit::Validate;

use Alchemy::Blog;
use Alchemy::Blog::Viewer::Comments;

use vars qw( @ISA );

############################################################
# Variables                                                #
############################################################
@ISA = ( 'Alchemy::Blog', 'KrKit::Handler' );

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# category_index( $site, $ident, $sid, $parent )
#-------------------------------------------------
sub category_index {
	my ( $site, $sident, $sid, $parent ) = @_;

	return() if ( ! is_integer( $parent ) );

	my @lines;

	my $sth = db_query( $$site{dbh}, 'get children',
						'SELECT id, ident, name FROM bg_categories ',
						'WHERE parent_id = ', sql_num( $parent ), 
						'AND bg_section_id = ', sql_num( $sid ),
						'ORDER by name' );
	
	while ( my ( $id, $ident, $name ) = db_next( $sth ) ) {

		push( @lines, 	'<li>', 
							ht_a( 	"$$site{rootp}/category/$sident/$ident", 
									$name ),
							category_index( $site, $sident, $sid, $id ), 
						'</li>' );
	}

	db_finish( $sth );

	return( '<ul>', @lines, '</ul>' ) if ( @lines );

	return();
} # END category_index

#-------------------------------------------------
# $site->do_article( $r, $section, $date, $ident )
#-------------------------------------------------
sub do_article {
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
						'SELECT bg_articles.id, bg_author_id, a_options, ',
						'topic, date_part( \'epoch\', pub_date ), ',
						'date_part( \'epoch\', modified ), content, ',
						'comment_count ',
						'FROM bg_articles, bg_article_type WHERE ',
						'bg_article_type.id = bg_article_type_id ',
						'AND published =\'t\' AND pub_date BETWEEN ',
						sql_str( "$year-$month-$day 00:00:00" ), ' AND ', 
						sql_str( "$year-$month-$day 23:59:59" ),
						'AND pub_date <= \'now\'', 
						'AND bg_articles.ident = ', sql_str( $ident ),
						'AND bg_section_id = ', sql_num( $sid ) );

	my( $id, $aid, $opts, $topic, $pub, $mod, $content, 
		$comcnt ) = db_next( $sth );

	db_finish( $sth );

	return( $site->_decline() ) if ( ! is_number( $id ) );

	$$site{page_title} .= $topic;

	my @cats;

	my $bth = db_query( $$site{dbh}, 'get categories', 
						'SELECT ident, name FROM bg_categories, ',
						'bg_article_categories WHERE ',
						'bg_categories.id = bg_category_id AND ',
						'bg_article_id = ', sql_num( $id )  );

	while ( my ( $cident, $cname ) = db_next( $bth ) ) {
		push( @cats, ht_a(	"$$site{rootp}/category/$section/$cident", 
							$cname ) );
	}

	db_finish( $bth );

	my @comms;

	if ( $opts & 1 || $opts & 2 ) {
		push( @comms, 	ht_div( { 'class' => 'article_comments' } ),
							ht_a( 	"$$site{root_posts}/view/$section".
									"/$adate/$ident", 'Comments: '. $comcnt ),
						ht_udiv() );	
	}

	my ( $author, $aident ) = $site->author_info( $aid );

	return( ht_div( { 'class' => 'article' } ),
			ht_div( { 'class' => 'article_header' } ),
			'<h1 class="topic">', $topic, '</h1>',
			'<h2 class="date">', 
				strftime( $$site{fmt_dt}, localtime($pub) ),
			'</h2>',
			'<h3 class="author">',
				'Posted by: ',
				ht_a( "$$site{rootp}/author/$aident", $author ),
			'</h3>',
			'<h4 class="category">',
				( ( @cats ) ? 'File Under: ' : '' ),
				( ( @cats ) ? join( ', ', @cats ) : '' ),
			'</h4>',
			ht_udiv(),
			ht_div( { 'class' => 'content' } ),
				$content, 
			ht_udiv(),
			ht_div( { 'class' => 'article_footer' } ),
				'Last modified: ',
				strftime( $$site{fmt_dt}, localtime($mod) ),
			ht_udiv(),
			@comms,
			ht_udiv() );
} # END $site->do_article

#-------------------------------------------------
# $site->do_archive( $r, $section, $archive_date )
#-------------------------------------------------
sub do_archive {
	my ( $site, $r, $section, $archive_date ) = @_;
	
	$section 		= $$site{default_sect} 	if ( ! is_ident( $section ) );
	$archive_date 	= '' 					if ( ! is_text( $archive_date ) );

	my ( $sid, $sname, $sframe ) = ( $site->section_info( $section ) )[0,3,4];

	return( $site->_decline() ) if ( ! is_number( $sid ) );
	
	my ( $year, $month, $day ) = split( '-', $archive_date );
	
	my @lines;
	
	if ( is_number( $day ) && is_number( $month ) && is_number( $year ) ) {

		my ( $ny, $nm, $nd ) = Add_Delta_Days( 	$year, $month, $day, 1 ); 

		$$site{page_title} .= 'Daily Archive';

		push( @lines, 	ht_div( { 'class' => 'archive' } ),
						'<h1>',
						ht_a( 	"$$site{rootp}/archive/$section/$year-$month", 
								strftime( 	$$site{fmt_d}, 0, 0, 0, $day, 
											$month - 1, $year - 1900 ) ),
						'</h1>' );

		my $sth = db_query( $$site{dbh}, 'get article',
							'SELECT bg_articles.id, bg_author_id, a_options, ',
							'bg_articles.ident, topic, ',
							'date_part( \'epoch\', pub_date ),',
							'content, comment_count ',
							'FROM bg_articles, bg_article_type WHERE ',
							'bg_article_type.id = bg_article_type_id ',
							'AND published =\'t\' AND pub_date BETWEEN ',
							sql_str( "$year-$month-$day 00:00:00" ), ' AND ', 
							sql_str( "$ny-$nm-$nd 00:00:00" ), 
							'AND pub_date <= \'now\'', 
							'AND bg_section_id = ', sql_num( $sid ),
							'ORDER BY pub_date DESC' );
	
		while ( my( $id, $aid, $opts, $ident, $topic, $pub,
					$content, $comcnt ) = db_next( $sth ) ) {

			my ( $author, $aident ) = $site->author_info( $aid );

			my @cats;

			my $bth = db_query( $$site{dbh}, 'get categories', 
								'SELECT ident, name FROM bg_categories, ',
								'bg_article_categories WHERE ',
								'bg_categories.id = bg_category_id AND ',
								'bg_article_id = ', sql_num( $id )  );

			while ( my ( $cdent, $cname ) = db_next( $bth ) ) {
				push( @cats, ht_a( 	"$$site{rootp}/category/$section/$cdent", 
									$cname ) );
			}

			db_finish( $bth );
	
			my $dlink = strftime( "%Y-%m-%d", localtime( $pub ) );

			my @comms;

			if ( $opts & 1 || $opts & 2 ) {
				push( @comms, 	ht_div( { 'class' => 'article_comments' } ),
								ht_a( 	"$$site{root_posts}/view/$section".
										"/$dlink/$ident",
										'Comments: '. $comcnt ),
								ht_udiv() );	
			}


			push( @lines, 	ht_div( { 'class' => 'article' } ),
							ht_div( { 'class' => 'article_header' } ),
							'<h1 class="topic">',
								ht_a( 	"$$site{rootp}/article/".
										"$section/$dlink/$ident", $topic ), 
							'</h1>',
							'<h2 class="date">', 
							strftime( $$site{fmt_dt}, localtime($pub) ),
							'</h2>',
							'<h3 class="author">',
							'Posted by: ',
							ht_a( "$$site{rootp}/author/$aident", $author ),
							'</h3>',
							'<h4 class="category">',
								( ( @cats ) ? 'File Under: ' : '' ),
								( ( @cats ) ? join( ', ', @cats ) : '' ),
							'</h4>',
							ht_udiv(),
							ht_div( { 'class' => 'content' } ),
								$content, 
							ht_udiv(),
							@comms,
							ht_udiv() );
		}

		if ( db_rowcount( $sth ) < 1 ) {
			push( @lines, '<p>No articles for this day.</p>' );
		}

		db_finish( $sth );

		return( @lines, ht_udiv() );
	}
	elsif ( is_number( $month ) && is_number( $year ) ) {

		$$site{page_title} .= 'Monthly Archive';

		my ( $ny, $nm ) = Add_Delta_Days( 	$year, $month, 1, 
											Days_in_Month( $year, $month ) );

		push( @lines,	ht_div( { 'class' => 'archive' } ),
						'<h1>',
							strftime( 	"%B", 0, 0, 0, 1, $month - 1, 
										$year - 1900 ),
 							ht_a( 	"$$site{rootp}/archive/$section/$year", 
									$year ),
						'</h1>' );

		my $sth = db_query( $$site{dbh}, 'get article',
							'SELECT bg_articles.id, bg_articles.ident, ',
							'bg_author_id, a_options, ',
							'topic, date_part( \'epoch\', pub_date ), summary ',
							'FROM bg_articles, bg_article_type WHERE ',
							'bg_article_type.id = bg_article_type_id ',
							'AND published =\'t\' AND pub_date BETWEEN ',
							sql_str( "$year-$month-1 00:00:00" ), ' AND ', 
							sql_str( "$ny-$nm-1 00:00:00" ), 
							'AND pub_date <= \'now\'', 
							'AND bg_section_id = ', sql_num( $sid ),
							'ORDER BY pub_date DESC' );
	
		while ( my( $id, $adent, $aid, $opts, $topic, $pub,
					$content ) = db_next( $sth ) ) {

			my @cats;
			my $dlink 				= strftime( "%Y-%m-%d", localtime($pub) );
			my ( $author, $aident ) = $site->author_info( $aid );

			my $bth = db_query( $$site{dbh}, 'get categories', 
								'SELECT ident, name FROM bg_categories, ',
								'bg_article_categories WHERE ',
								'bg_categories.id = bg_category_id AND ',
								'bg_article_id = ', sql_num( $id )  );

			while ( my ( $cdent, $cname ) = db_next( $bth ) ) {
				push( @cats, ht_a( 	"$$site{rootp}/category/$section/$cdent", 
									$cname ) );
			}

			db_finish( $bth );

			push( @lines, 	ht_div( { 'class' => 'article' } ),
							ht_div( { 'class' => 'article_header' } ),
							'<h1 class="topic">',
								ht_a( 	"$$site{rootp}/article/$section".
										"/$dlink/$adent", $topic ), 
							'</h1>',
							'<h2 class="date">', 
							strftime( $$site{fmt_dt}, localtime($pub) ),
							'</h2>',
							'<h3 class="author">',
							'Posted by: ',
							ht_a( "$$site{rootp}/author/$aident", $author ),
							'</h3>',
							'<h4 class="category">',
								( ( @cats ) ? 'File Under: ' : '' ),
								( ( @cats ) ? join( ', ', @cats ) : '' ),
							'</h4>',
							ht_udiv(),
							ht_div( { 'class' => 'content' } ),
								$content, 
							ht_udiv(),
							ht_div( { 'class' => 'article_footer' } ),
								ht_a( 	"$$site{rootp}/article/".
										"$section/$dlink/$adent", 
										'Read Full Article' ),
							ht_udiv(),
							ht_udiv() );
		}

		if ( db_rowcount( $sth ) < 1 ) {
			push( @lines, '<p>No articles for this month.</p>' );
		}

		db_finish( $sth );

		return( @lines, ht_udiv() );
	}

	my @sql;

	if ( is_number( $year ) ) {
		$$site{page_title} .= 'Yearly Archive';
		my $nyear 			= $year + 1;
		my $lyear 			= $year - 1;

		push( @sql, 	'AND pub_date BETWEEN ',
						sql_str( "$year-1-1 00:00:00" ), ' AND ',
						sql_str( "$nyear-1-1 00:00:00" ), );
	}
	else {
		$$site{page_title} .= 'Archive';
	}

	my $cmonth 			= '0';
	my $cday 			= '0';
	
	push( @lines, ht_div( { 'class' => 'archive' } ) );

	my $sth = db_query( $$site{dbh}, 'get article',
						'SELECT bg_articles.id, bg_articles.ident, ',
						'a_options, topic, date_part( \'epoch\', pub_date )',
						'FROM bg_articles, bg_article_type WHERE ',
						'bg_article_type.id = bg_article_type_id ',
						'AND published =\'t\' ', @sql,
						'AND bg_section_id = ', sql_num( $sid ),
						'AND pub_date <= \'now\' ORDER BY pub_date DESC' );

	while ( my ( $id, $adent, $opts, $topic, $pub ) = db_next( $sth ) ) {

		$month 		= strftime( "%m", localtime( $pub ) );
		$year 		= strftime( "%Y", localtime( $pub ) );
		my $mon 	= strftime( "%B %Y", localtime( $pub ) );
		my $day 	= strftime( "%d", localtime( $pub ) );
		my $skip 	= 0;

		if ( $cmonth ne $mon ) {
			push( @lines, 	'</ul></li></ul>' ) if ( $cmonth );
			push( @lines, 	'<h1>',
								ht_a( 	"$$site{rootp}/archive/".
										"$section/$year-$month", $mon ),
							'</h1>', 
							'<ul class="days">' );
			$cmonth = $mon;
			$cday 	= 0;
			$skip 	= 1;
		}

		if ( $cday ne $day ) {
			push( @lines, 	'</ul></li>' ) 	if ( $cday && ! $skip );

			push( @lines, 	'<li class="day">', 
							ht_a( 	"$$site{rootp}/archive/".
									"$section/$year-$month-$day", $day ),
							'<ul class="articles">' );
			$cday = $day;
			$skip = 0;
		}

		push( @lines, 	'<li class="article">', 
						ht_a( 	"$$site{rootp}/article/$section/".
								"$year-$month-$day/$adent", $topic ), 
						'</li>' );
	}

	if ( db_rowcount( $sth ) > 0 ) {
		push( @lines, '</ul>', '</li>', '</ul>' );
	}
	else {
		push( @lines, 	'<div class="article">',
						'<h1 class="topic">No articles found</h1>',
						'<p>There were no articles found to display.</p>',
						'</div>' );
	}

	db_finish( $sth );

	return( @lines, ht_udiv() );
} # END $site->do_archive

#-------------------------------------------------
# $site->do_author( $r, $author_ident )
#-------------------------------------------------
sub do_author {
	my ( $site, $r, $aident ) = @_;

	return( $site->_decline() ) if ( ! is_ident( $aident ) );	

	my $sth = db_query( $$site{dbh}, 'get author',
						'SELECT id, name, email, photo, bio FROM bg_authors',
						'WHERE ident = ', sql_str( $aident ) );
	
	my ( $id, $name, $email, $photo, $bio ) = db_next( $sth );

	db_finish( $sth );

	return( $site->_decline() ) if ( ! is_integer( $id ) );

	$$site{page_title} .= $name;

	my $image = '';
	
	if ( $photo ) {
		$image = ht_img( "$$site{file_uri}/$photo", qq!alt="$name"! );
	}

	return(	ht_div( { 'class' => 'author' } ),
				ht_div( { 'class' => 'author_header' } ),
				'<h1>', $name, '</h1>',
				'<h2>', $email, '</h2>',
				ht_udiv(),
				ht_div( { 'class' => 'author_content' } ),
					$image, $bio,
				ht_udiv(),
			ht_udiv() );
} # END $site->do_author

#-------------------------------------------------
# $site->do_category( $r, $section_ident, $category_ident, $offset )
#-------------------------------------------------
sub do_category {
	my ( $site, $r, $sident, $cident, $offset ) = @_;

	return( $site->_decline() ) 	if ( ! is_ident( $sident ) );
	return( $site->_decline() ) 	if ( ! is_ident( $cident ) );
	$offset = 0 					if ( ! is_number( $offset ) );

	# Get the section ident information.
	my ( $sid ) = ( $site->section_info( $sident ) )[0];

	return( $site->_decline() ) if ( ! is_number( $sid ) );

	# Get the category info.
	my $sth = db_query( $$site{dbh}, 'get category info',
						'SELECT id, article_limit, c_options, frame, name,',
						'description FROM bg_categories WHERE ident = ', 
						sql_str( $cident ), 'AND bg_section_id = ',
						sql_num( $sid ) );
	
	my ( $id, $lim, $opts, $frame, $cname, $desc ) = db_next( $sth );

	db_finish( $sth );

	return( $site->_decline() ) if ( ! is_number( $id ) );

	# Set the frame.
	$$site{page_title} 	.= $cname;

	if ( is_text( $frame ) ) {
		$$site{frame} = $frame if ( $frame !~ /^auto$/i );
	}
	
	my @lines;

	# Display the category header if chosed.
	if ( $opts & 1 || $opts & 16 || $opts & 2 ) {
		push( @lines, ht_div( { 'class' => 'category_header' }  ) )
	}

	push( @lines, '<h1>', $cname, '</h1>' ) if ( $opts & 1 );
	push( @lines, $desc ) 					if ( $opts & 16 );

	# Display the sub-categories if chosen.
	if ( $opts & 2 ) {
	
		my @subs;

		my $bth = db_query( $$site{dbh}, 'get children', 
							'SELECT ident, name FROM bg_categories ',
							'WHERE parent_id = ', sql_num( $id ), 
							'ORDER BY name' );

		while ( my ( $ident, $sname ) = db_next( $bth ) ) {
			push( @subs, ht_a( 	"$$site{rootp}/category/$sident/$ident", 
								$sname ) );
		}

		db_finish( $bth );

		push( @lines, 'Sub-categories: ' );

		if ( @subs ) {
			push( @lines, join( ', ', @subs ) );
		}
		else {
			push( @lines, 'No sub categories.' );
		}
	}
	
	if ( $opts & 1 || $opts & 16 || $opts & 2 ) {
		push( @lines, ht_udiv() );
	}

	# List all of the articles in a given category.
	my $count = 0;
	my $ath = db_query( $$site{dbh}, 'get articles',
						'SELECT bg_articles.ident, bg_author_id, topic, ',
						'date_part( \'epoch\', pub_date ), ',
						( ( $opts & 4 ) ? 'content' : 'summary' ),
						'FROM bg_articles, bg_article_type, ',
						'bg_article_categories ',
						'WHERE bg_article_id = bg_articles.id AND ',
						'bg_category_id = ', sql_num( $id ), 
						'AND bg_section_id = ', sql_num( $sid ),
						'AND bg_article_type.id = bg_article_type_id ',
						'AND published =\'t\' AND pub_date <= \'now\' ',
						'ORDER BY pub_date ',
						( ( $opts & 8 ) ? 'ASC' : 'DESC' ) );

	while ( my( $ident, $aid, $topic, $date, $content ) = db_next( $ath ) ) {
		
		$count++;
		next if ( ( $lim > 0 ) && ( $count > $lim + $offset ) );
		next if ( ( $lim > 0 ) && ( $count <= $offset ) );

		# Grab author stuff.
		my ( $author, $aident ) = $site->author_info( $aid );

		push( @lines, 	ht_div( { 'class' => 'article' } ),
						ht_div( { 'class' => 'article_header' } ),
						'<h1 class="topic">', $topic, '</h1>',
						'<h2 class="date">', 
							strftime( $$site{fmt_dt}, localtime($date) ),
						'</h2>',
						'<h3 class="author">',
							'Posted by: ',
							ht_a( "$$site{rootp}/author/$aident", $author ),
						'</h3>',
						ht_udiv(),
						q!<div class="content">!, $content, q!</div>! );

	
		# Link to read the full article if in summary mode.
		if ( ! ( $opts & 4 ) ) { 
			my $dlink = strftime( "%Y-%m-%d", localtime( $date ) );
			push( @lines, 	q!<div class="article_footer">!,
							ht_a( 	"$$site{rootp}/article/".
									"$sident/$dlink/$ident", 
									'Read Full Article' ),
							q!</div>! );
		}

		push( @lines, q!</div>!, );
	}

	if ( db_rowcount( $ath ) < 1 ) {
		push( @lines, 	'<div class="article">',
						'<h1 class="topic">No articles found</h1>',
						'<p>There were no articles found to display in ',
						'this category</p>',
						'</div>' );
	}
	else { # Show the paging if we need to.
		push( @lines, '<div class="category_footer">' );

		if ( ( $lim > 0 ) && ( $offset > 0 ) ) { # Have history.
			push( @lines, 	ht_div( { 'class' => 'prev' } ),	
							ht_a( 	"$$site{rootp}/category/$sident/$cident/".
									( $offset - $lim ), 'Previous Page' ),
							ht_udiv() );
		}

		if ( ( $lim > 0 ) && ( $offset + $lim < $count ) ) { # Have future.
			push( @lines,	ht_div( { 'class' => 'next' } ), 
							ht_a( 	"$$site{rootp}/category/$sident/$cident/".
									( $offset + $lim ), 'Next Page' ),
							ht_udiv() );
		}

		push( @lines, '</div>' );
	}

	db_finish( $ath );

	return( @lines );
} # END $site->do_category

#-------------------------------------------------
# $site->do_index( $r, $section )
#-------------------------------------------------
sub do_index {
	my ( $site, $r, $section ) = @_;

	$$site{page_title} .= 'Index';

	my @lines = ( ht_div( { 'class' => 'index' } ), '<h1>Categories</h1>' );

	my $sth = db_query( $$site{dbh}, 'get sections', 
						'SELECT id, ident, name FROM bg_sections ' );

	while ( my ( $id, $ident, $name ) = db_next( $sth ) ) {
		# Show all of the categories in a tree.
		my @cats = 	category_index( $site, $ident, $id, 0 );
		 
		if ( @cats ) {
			push( @lines, 	'<h2>', 
							ht_a( "$$site{rootp}/main/$ident", $name ), 
							'</h2>', @cats  );
		}
	}

	db_finish( $sth );

	return( @lines, ht_udiv() );
} # END $site->do_index

#-------------------------------------------------
# $site->do_main( $r, $section )
#-------------------------------------------------
sub do_main {
	my ( $site, $r, $section ) = @_;

	$$site{page_title} .= 'Recent';

	my @lines;
	my $count 	= 0;
	$section 	= $$site{default_sect} if ( ! is_ident( $section ) );

	my ( $sid, $salim, $sopt, $sname, $frame, 
			$sdesc ) = $site->section_info( $section );

	return( $site->_decline() ) if ( ! is_number( $sid ) );
	
	if ( is_text( $frame ) ) {
		$$site{frame} = $frame if ( $frame !~ /^auto$/i );
	}

	#$$site{page_title} 	.= $sname; #Would this look right ?

	if ( $sopt & 1 ||  $sopt & 2 ) {
		push( @lines, ht_div( { 'class' => 'section_header' } ) );
	}

	push( @lines, '<h1>', $sname, '</h1>' ) if ( $sopt & 1 );
	push( @lines, $sdesc ) 					if ( $sopt & 2 );

	if ( $sopt & 1 ||  $sopt & 2 ) {
		push( @lines, ht_udiv() );
	}

	my $sth = db_query( $$site{dbh}, 'get articles',
						'SELECT bg_articles.id, bg_articles.ident, ',
						'bg_author_id, topic, a_options, comment_count,',
						'date_part( \'epoch\', pub_date ), ',
						( ( $sopt & 4 ) ? 'content' : 'summary' ),
						'FROM bg_articles, bg_article_type ',
						'WHERE bg_article_type.id = bg_article_type_id ',
						'AND published =\'t\' AND pub_date <= \'now\' ',
						'AND bg_section_id = ', sql_num( $sid ),
						'ORDER BY pub_date ',
						( ( $sopt & 8 ) ? 'ASC' : 'DESC' ) );

	while ( my( $id, $ident, $aid, $topic, $aopts, $comcnt, $date, 
				$content ) = db_next( $sth ) ) {

		$count++;

		next if ( $salim > 0 && $count > $salim );

		# Grab author stuff.
		my ( $author, $aident ) = $site->author_info( $aid );

		my @cats;

		my $bth = db_query( $$site{dbh}, 'get categories', 
							'SELECT ident, name FROM bg_categories, ',
							'bg_article_categories WHERE ',
							'bg_categories.id = bg_category_id AND ',
							'bg_article_id = ', sql_num( $id )  );

		while ( my ( $cident, $cname ) = db_next( $bth ) ) {
			push( @cats, ht_a( 	"$$site{rootp}/category/$section/$cident", 
								$cname ) );
		}

		db_finish( $bth );
		
		my $dlink = strftime( "%Y-%m-%d", localtime( $date ) );

		push( @lines, 	ht_div( { 'class' => 'article' } ),
						ht_div( { 'class' => 'article_header' } ),
						'<h1 class="topic">', 
							ht_a( 	"$$site{rootp}/article/".
									"$section/$dlink/$ident", $topic ), 
						'</h1>',
						'<h2 class="date">', 
							strftime( $$site{fmt_dt}, localtime($date) ),
						'</h2>',
						'<h3 class="author">',
							'Posted by: ',
							ht_a( "$$site{rootp}/author/$aident", $author ),
						'</h3>',
						'<h4 class="category">',
						( ( @cats ) ? 'File Under: ' : '' ),
						( ( @cats ) ? join( ', ', @cats ) : '' ),
						'</h4>',
						ht_udiv(),
						ht_div( { 'class' => 'content' } ),
								$content, 
						ht_udiv() );

		if ( ! ( $sopt & 4 ) ) { 
			push( @lines, 	q!<div class="article_footer">!,
							ht_a( 	"$$site{rootp}/article/$section/".
									"$dlink/$ident", 'Read Full Article' ),
							q!</div>! );
		}

		if ( $aopts & 1 || $aopts & 2 ) {
			push( @lines, 	ht_div( { 'class' => 'article_comments' } ),
							ht_a( 	"$$site{root_posts}/view/$section".
									"/$dlink/$ident", 'Comments: '. $comcnt ),
							ht_udiv() );	
		}

		push( @lines, ht_udiv() );
	}

	if ( db_rowcount( $sth ) < 1 ) {
		push( @lines, 	ht_div( { 'class' => 'article' } ),
						ht_div( { 'class' => 'article_header' } ),	
							'<h1 class="topic">No articles found</h1>',
						ht_udiv(),
						ht_div( { 'class' => 'content' } ),
							'<p>There were no articles found to display</p>',
						ht_udiv(),
						ht_udiv() );
	}

	db_finish( $sth );

	return( @lines );
} # END $site->do_main

#-------------------------------------------------
# $site->do_search( $r, $offset )
#-------------------------------------------------
sub do_search {
	my ( $site, $r, $offset ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title}	.= 'Search';

	if ( ! ( my @errors = search_checkvals( $in ) ) ) {

		my @sql;

		for my $word (split( /\s/, $in->{words} ) ) {
			$word =~ s/"//g;			

			if ( $word =~ /\+/ ) {
				my @psql;

				for my $part ( split( /\+/, $word )  ) {
					push( @psql,	'( topic ~* '. sql_str( $part ).
									' OR content ~* '. sql_str( $part ). ')' );	
				}
	
				push( @sql, join( ' AND ', @psql ) ) if ( @psql );
			}
			else {
				push( @sql, 'topic ~* '. sql_str( $word ),
							'content ~* '. sql_str( $word )	);	
			}
		}

		my $sth = db_query( $$site{dbh}, 'get search', 
							'SELECT bg_articles.id, bg_author_id, ',
							'bg_sections.ident, bg_articles.ident, ',
							'topic, date_part( \'epoch\', pub_date ), summary ',
							'FROM bg_articles, bg_article_type, bg_sections ',
							'WHERE bg_sections.id = bg_section_id AND ' ,
							'bg_article_type.id = bg_article_type_id ',
							'AND published =\'t\' AND pub_date <= \'now\'',
							'AND ( ', join( ' OR ', @sql ),
							') ORDER BY pub_date DESC' );

		my $count = db_rowcount( $sth );
		
		my @lines = ( 	'<h1>', $count, 'Result(s) for', 
						ht_i( qq!"$in->{words}"! ), '</h1>' );

		while ( my( $id, $aid, $sdent, $adent, $topic, $pub, 
					$sum ) = db_next( $sth ) ) {

			my ( $author, $aident ) = $site->author_info( $aid );

			my @cats;

			my $bth = db_query( $$site{dbh}, 'get categories', 
								'SELECT ident, name FROM bg_categories, ',
								'bg_article_categories WHERE ',
								'bg_categories.id = bg_category_id AND ',
								'bg_article_id = ', sql_num( $id )  );

			while ( my ( $cdent, $cname ) = db_next( $bth ) ) {
				push( @cats, ht_a( 	"$$site{rootp}/category/$sdent/$cdent", 
									$cname ) );
			}

			db_finish( $bth );

			my $dlink = strftime( "%Y-%m-%d", localtime($pub) );

			push( @lines, 	ht_div( { 'class' => 'article' } ),
							ht_div( { 'class' => 'article_header' } ),
							'<h1 class="topic">',
							ht_a( "$$site{rootp}/article/$sdent/$dlink/$adent",
									$topic ), 
							'</h1>',
							'<h2 class="date">', 
							strftime( $$site{fmt_dt}, localtime($pub) ),
							'</h2>',
							'<h3 class="author">',
							'Posted by: ',
							ht_a( "$$site{rootp}/author/$aident", $author ),
							'</h3>',
							'<h4 class="category">',
								( ( @cats ) ? 'File Under: ' : '' ),
								( ( @cats ) ? join( ', ', @cats ) : '' ),
							'</h4>',
							ht_udiv(),
							ht_div( { 'class' => 'content' } ),
								$sum, 
							ht_udiv(),
							ht_div( { 'class' => 'article_footer' } ),
							ht_a( "$$site{rootp}/article/$sdent/$dlink/$adent", 
									'Read Full Article' ),
							ht_udiv(),
							ht_udiv() );

		}

		if ( db_rowcount( $sth ) < 1 ) {
			push( @lines, 	ht_div( { 'class' => 'article' } ),
							ht_div( { 'class' => 'article_header' } ),
							'<h1 class="topic">No articles found</h1>',
							ht_udiv(),
							ht_div( { 'class' => 'content' } ),
							'<p>There were no articles found to display</p>',
							ht_udiv(),
							ht_udiv() );
		}
	
		db_finish( $sth );

		return( @lines, search_form( $site, $in ) );
	}
	else {
		if ( $r->method eq 'POST' ) {
			return( @errors, search_form( $site, $in ) );
		}
		else {
			return( search_form( $site, $in ) );
		}
	}
} # END $site->do_search

#-------------------------------------------------
# search_checkvals( $in )
#-------------------------------------------------
sub search_checkvals {
	my $in = shift;

	my @errors;

	if ( ! is_text( $in->{words} ) ) {
		push( @errors, 'You must enter something to search for.'. ht_br() );
	}
	else {
		if ( $in->{words} =~ /^\*+$/  ) {
			push( @errors, 	'"*" is not a valid search string.'.  ht_br() );
		}
	}

	return( @errors );
} # END search_checkvals

#-------------------------------------------------
# search_form( $site, $in )
#-------------------------------------------------
sub search_form {
	my ( $site, $in ) = @_;

	return( ht_form_js( $$site{uri} ),	
			ht_div( { 'class' => 'box' } ),
			ht_table( {} ),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Search for', ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'words', 'text', $in ) ),
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

Alchemy::Blog::Viewer - Public blog view.

=head1 SYNOPSIS

  use Alchemy::Blog::Viewer;

=head1 DESCRIPTION

This is the front end for this application, what the general public will
see. 

=head1 APACHE

This is a sample of the location required for this module to run.
Consult Alchemy::Blog(3) to learn about the configuration options.

  <Location / >
    SetHandler  perl-script

    PerlHandler Alchemy::Blog::Viewer
  </Location>

=head1 DATABASE

This module reads from all of the blog tables. It does not modify these
tables.

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
