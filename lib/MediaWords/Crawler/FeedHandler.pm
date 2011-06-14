package MediaWords::Crawler::FeedHandler;

use strict;
use warnings;

# MODULES

use Data::Dumper;
use Date::Parse;
use DateTime;
use Encode;
use FindBin;
use IO::Compress::Gzip;
use URI::Split;
use Switch;
use Carp;
use Perl6::Say;
use List::Util qw (max maxstr);

use Feed::Scrape::MediaWords;
use MediaWords::Crawler::BlogSpiderBlogHomeHandler;
use MediaWords::Crawler::BlogSpiderPostingHandler;
use MediaWords::Crawler::Pager;
use MediaWords::DBI::Downloads;
use MediaWords::DBI::Stories;
use MediaWords::Util::Config;
use MediaWords::DBI::Stories;

# CONSTANTS

# max number of pages the handler will download for a single story
use constant MAX_PAGES => 10;

# STATICS

my $_feed_media_ids     = {};
my $_added_xml_enc_path = 0;

# METHODS

# parse the feed and add the resulting stories and content downloads to the database
sub _add_stories_and_content_downloads
{
    my ( $dbs, $download, $decoded_content ) = @_;

    my $feed = Feed::Scrape::MediaWords->parse_feed( $decoded_content );

    die( "Unable to parse feed for $download->{ url }" ) unless $feed;

    my $items = [ $feed->get_item ];

    my $num_new_stories = 0;

  ITEM:
    for my $item ( @{ $items } )
    {
        my $url  = $item->link() || $item->guid();
        my $guid = $item->guid() || $item->link();

        if ( !$url && !$guid )
        {
            next ITEM;
        }

        $url =~ s/[\n\r\s]//g;

        my $date = DateTime->from_epoch( epoch => Date::Parse::str2time( $item->pubDate() ) || time );

        my $media_id = MediaWords::DBI::Downloads::get_media_id( $dbs, $download );

        my $story = $dbs->query( "select * from stories where guid = ? and media_id = ?", $guid, $media_id )->hash;

        if ( !$story )
        {
            my $start_date = $date->subtract( hours => 12 )->iso8601();
            my $end_date = $date->add( hours => 12 )->iso8601();

      # TODO -- DRL not sure if assuming UTF-8 is a good idea but will experiment with this code form the gsoc_dsheets branch
            my $title;

            # This unicode decode may not be necessary! XML::Feed appears to at least /sometimes/ return
            # character strings instead of byte strings. Decoding a character string is an error. This code now
            # only fails if a non-ASCII byte-string is returned from XML::Feed.

            # very misleadingly named function checks for unicode character string
            # in perl's internal representation -- not a byte-string that contains UTF-8
            # data
            if ( Encode::is_utf8( $item->title ) )
            {
                $title = $item->title;
            }
            else
            {

                # TODO: A utf-8 byte string is only highly likely... we should actually examine the HTTP
                #   header or the XML pragma so this doesn't explode when given another encoding.
                $title = decode( 'utf-8', $item->title );
                if ( Encode::is_utf8( $item->title ) )
                {

                    # TODO: catch this
                    print STDERR "Feed " . $download->{ feeds_id } . " has inconsistent encoding for title:\n";
                    print STDERR "$title\n";
                }
            }
            $story = $dbs->query(
                "select * from stories where title = ? and media_id = ? " .
                  "and publish_date between date '$start_date' and date '$end_date' for update",
                $title, $media_id
            )->hash;
        }

        if ( !$story )
        {
            $num_new_stories++;

            eval {

                #Work around a bug in XML::FeedPP -
                #  Item description() will sometimes return a hash instead of text.
                # TODO fix XML::FeedPP
                my $description = ref( $item->description ) ? ( '' ) : ( $item->description || '' );

                $story = {
                    url          => $url,
                    guid         => $guid,
                    media_id     => $media_id,
                    publish_date => $date->datetime,
                    collect_date => DateTime->now->datetime,
                    title        => $item->title() || '(no title)',
                    description  => $description,
                };

                # say STDERR "create story: " . Dumper( $story );

                $story = $dbs->create( "stories", $story );
                MediaWords::DBI::Stories::update_rss_full_text_field( $dbs, $story );
            };

            if ( $@ )
            {

                # if we hit a race condition with another process having just inserted this guid / media_id,
                # just put the download back in the queue.  this is a lot better than locking stories
                if ( $@ =~ /unique constraint "stories_guid"/ )
                {
                    $dbs->rollback;
                    $dbs->query( "update downloads set state = 'pending' where downloads_id = ?",
                        $download->{ downloads_id } );
                    die( "requeue '$url' due to guid conflict" );
                }
                else
                {
                    print Dumper( $story );
                    die( $@ );
                }
            }
            else
            {
                $dbs->create(
                    'downloads',
                    {
                        feeds_id      => $download->{ feeds_id },
                        stories_id    => $story->{ stories_id },
                        parent        => $download->{ downloads_id },
                        url           => $url,
                        host          => lc( ( URI::Split::uri_split( $url ) )[ 1 ] ),
                        type          => 'content',
                        sequence      => 1,
                        state         => 'pending',
                        priority      => $download->{ priority },
                        download_time => DateTime->now->datetime,
                        extracted     => 'f'
                    }
                );
            }
        }

        if ( !$story ) { warn "skipping story"; next; }

        die "story undefined"                                       unless $story;
        confess "story id undefined for story: " . Dumper( $story ) unless defined( $story->{ stories_id } );
        die "feed undefined"                                        unless $download->{ feeds_id };

        $dbs->find_or_create(
            'feeds_stories_map',
            {
                stories_id => $story->{ stories_id },
                feeds_id   => $download->{ feeds_id }
            }
        );

        #FIXME - add meta keywords
    }

    return $num_new_stories;
}

sub handle_feed_content
{
    my ( $dbs, $download, $decoded_content ) = @_;

    my $num_new_stories = _add_stories_and_content_downloads( $dbs, $download, $decoded_content );

    my $content_ref;
    if ( $num_new_stories > 0 )
    {
        $content_ref = \$decoded_content;
    }
    else
    {
        $content_ref = \"(redundant feed)";
    }

    MediaWords::DBI::Downloads::store_content( $dbs, $download, $content_ref );

    return;
}

1;