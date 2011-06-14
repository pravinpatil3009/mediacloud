#!/usr/bin/perl

use strict;

BEGIN
{
    use FindBin;
    use lib "$FindBin::Bin/../lib";
}

use Data::Dumper;
use utf8;
use MediaWords::DB;
use Perl6::Say;

sub main
{

    my $db = MediaWords::DB::connect_to_db;

    my $table_query = <<'SQL';
SELECT *, Pg_get_serial_sequence(tablename, id_column)
FROM   (SELECT t.oid     AS tableid,
               t.relname AS tablename,
               t.relname
                || '_id' AS id_column,
               c.oid     AS constraintid,
               conname   AS constraintname
        FROM   pg_constraint c
               JOIN pg_class t
                 ON ( c.conrelid = t.oid )
        WHERE  conname LIKE '%_pkey'
               AND t.relname <> 'url_discover_counts'
        ORDER  BY t.relname) AS tables_with_pkeys
WHERE  NOT ( tablename IN ( 'url_discovery_counts', 'foovar',
                                   'queries_top_weekly_words_json'
                                       ,
                            'download_texts',
                            'top_500_weekly_author_words',
                            'total_top_500_weekly_author_words',
                            'ngram_test_story_sentences',
                            'total_top_500_weekly_words'
                                       ) );  
SQL

    my $tables = $db->query( $table_query )->hashes;

    foreach my $table ( @$tables )
    {

        #say Dumper( $table );

        if ( !$table->{ pg_get_serial_sequence } )
        {
            say 'skipping table ' . $table->{ tablename } . ' that does not have a sequence id ';
            next;
        }
        my $sequence_query =
          'select * from (select max(' . $table->{ id_column } . ' ) as max_id, nextval( ' . "'" .
          $table->{ pg_get_serial_sequence } . "'" . ' ) as sequence_val from  ' . $table->{ tablename } .
          ' ) as id_and_sequence where max_id >= sequence_val ';

        #say STDERR $sequence_query;

        my $table_info = $db->query( $sequence_query )->hash;

        if ( $table_info )
        {
            say "Invalid sequence value for table $table->{ tablename } ";
            say Dumper( $table_info );
            exit;
        }
    }

}

main();