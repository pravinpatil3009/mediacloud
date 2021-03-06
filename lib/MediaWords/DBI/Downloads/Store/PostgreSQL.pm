package MediaWords::DBI::Downloads::Store::PostgreSQL;

# class for storing / loading downloads in PostgreSQL, "raw_downloads" table

use strict;
use warnings;

use Moose;
with 'MediaWords::DBI::Downloads::Store';

use Modern::Perl "2013";
use MediaWords::CommonLibs;
use DBD::Pg qw(:pg_types);

# Table name to store downloads to
use constant RAW_DOWNLOADS_TABLE => 'raw_downloads';

# Constructor
sub BUILD
{
    my ( $self, $args ) = @_;
}

# Moose method
sub store_content($$$$;$)
{
    my ( $self, $db, $download, $content_ref, $skip_encode_and_gzip ) = @_;

    my $downloads_id = $download->{ downloads_id };
    my $table_name   = RAW_DOWNLOADS_TABLE;

    # Encode + gzip
    my $content_to_store;
    if ( $skip_encode_and_gzip )
    {
        $content_to_store = $$content_ref;
    }
    else
    {
        $content_to_store = $self->encode_and_gzip( $content_ref, $download->{ downloads_id } );
    }

    # "Upsert" the download
    $db->begin_work;

    my $sth;

    $sth = $db->dbh->prepare(
        <<"EOF",
    	UPDATE $table_name
    	SET raw_data = ?
    	WHERE downloads_id = ?
EOF
    );
    $sth->bind_param( 1, $content_to_store, { pg_type => DBD::Pg::PG_BYTEA } );
    $sth->bind_param( 2, $downloads_id );
    $sth->execute();

    $sth = $db->dbh->prepare(
        <<"EOF",
    	INSERT INTO $table_name (downloads_id, raw_data)
			SELECT ?, ?
			WHERE NOT EXISTS (
				SELECT 1
				FROM $table_name
				WHERE downloads_id = ?
			)
EOF
    );
    $sth->bind_param( 1, $downloads_id );
    $sth->bind_param( 2, $content_to_store, { pg_type => DBD::Pg::PG_BYTEA } );
    $sth->bind_param( 3, $downloads_id );
    $sth->execute();

    $db->commit;

    my $path = 'postgresql:' . $table_name;
    return $path;
}

# Moose method
sub fetch_content($$$;$)
{
    my ( $self, $db, $download, $skip_gunzip_and_decode ) = @_;

    my $downloads_id = $download->{ downloads_id };
    my $table_name   = RAW_DOWNLOADS_TABLE;

    my $gzipped_content = $db->query(
        <<"EOF",
        SELECT raw_data
        FROM $table_name
        WHERE downloads_id = ?
EOF
        $downloads_id
    )->flat;

    unless ( $gzipped_content->[ 0 ] )
    {
        die "Download with ID $downloads_id was not found in '$table_name' table.\n";
    }

    $gzipped_content = $gzipped_content->[ 0 ];

    # Gunzip + decode
    my $decoded_content;
    if ( $skip_gunzip_and_decode )
    {
        $decoded_content = $gzipped_content;
    }
    else
    {
        $decoded_content = $self->gunzip_and_decode( \$gzipped_content, $download->{ downloads_id } );
    }

    return \$decoded_content;
}

# Removes content
sub remove_content($$$)
{
    my ( $self, $db, $download ) = @_;

    my $downloads_id = $download->{ downloads_id };
    my $table_name   = RAW_DOWNLOADS_TABLE;

    $db->query(
        <<"EOF",
        DELETE FROM $table_name
        WHERE downloads_id = ?
EOF
        $downloads_id
    );
}

# Returns true if a download already exists in a database
sub content_exists($$$)
{
    my ( $self, $db, $download ) = @_;

    my $downloads_id = $download->{ downloads_id };
    my $table_name   = RAW_DOWNLOADS_TABLE;

    my $download_exists = $db->query(
        <<"EOF",
        SELECT 1
        FROM $table_name
        WHERE downloads_id = ?
EOF
        $downloads_id
    )->flat;

    if ( $download_exists->[ 0 ] )
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

no Moose;    # gets rid of scaffolding

1;
