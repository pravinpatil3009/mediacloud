#!/usr/bin/env perl

=head1 NAME

mediawords_gearman_worker.pl - Start one or all GJS workers; read configuration
from mediawords.yml.

This is a wrapper around gjs_worker.pl script.

The script reads configuration from mediawords.yml and passes it as parameters
to the gjs_worker.pl script.

=head1 SYNOPSIS

    # Run all Gearman functions from lib/MediaWords/GearmanFunctions/
    ./script/run_with_carton.sh ./script/mediawords_gearman_worker.pl

or:

    # Run Gearman function "GearmanFunction" from "lib/MediaWords/GearmanFunctions/"
    ./script/run_with_carton.sh ./script/mediawords_gearman_worker.pl GearmanFunction

or:

    # Run Gearman function from "path/to/GearmanFunction.pm"
    ./script/run_with_carton.sh ./script/mediawords_gearman_worker.pl path/to/GearmanFunction.pm

or:

    # Run all Gearman functions from "path_to/dir_with/gearman_functions/"
    ./script/run_with_carton.sh ./script/mediawords_gearman_worker.pl path_to/dir_with/gearman_functions/

=cut

use strict;
use warnings;

BEGIN
{
    use FindBin;
    use lib "$FindBin::Bin/../lib";
}

use Modern::Perl "2012";
use MediaWords::CommonLibs;
use MediaWords::Util::Config;
use Gearman::JobScheduler::Worker;
use MediaWords::Util::GearmanJobSchedulerConfiguration;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG, utf8 => 1, layout => "%d{ISO8601} [%P]: %m%n" } );

use Pod::Usage;
use Readonly;

# Default path to Media Cloud's directory of Gearman functions
my Readonly $MC_GEARMAN_FUNCTIONS_DIR = 'lib/MediaWords/GearmanFunctions/';

sub main()
{
    if ( scalar( @ARGV ) > 1 )
    {
        pod2usage( 1 );
    }

    # Initialize with Media Cloud's GJS configuration
    my $gjs_config = MediaWords::Util::GearmanJobSchedulerConfiguration->new();

    # Function name, path to function module or path to directory with all functions
    my $gearman_function_name_or_directory = $MC_GEARMAN_FUNCTIONS_DIR;
    if ( scalar( @ARGV ) == 1 )
    {
        $gearman_function_name_or_directory = $ARGV[ 0 ];
    }

    INFO( "Will use Gearman servers: " . join( ' ', @{ $gjs_config->gearman_servers } ) );
    INFO( "Will write logs to directory: " . $gjs_config->worker_log_dir );
    if ( scalar @{ $gjs_config->notifications_emails } )
    {
        INFO( 'Will send notifications about failed jobs to: ' . join( ' ', @{ $gjs_config->notifications_emails } ) );
        INFO( '(emails will be sent from "' . $gjs_config->notifications_from_address .
              '" and prefixed with "' . $gjs_config->notifications_subject_prefix . '")' );
    }
    else
    {
        INFO( 'Will not send notifications anywhere about failed jobs.' );
    }

    if ( -d $gearman_function_name_or_directory )
    {

        # Run all workers
        Gearman::JobScheduler::Worker::run_all_workers( $gjs_config, $gearman_function_name_or_directory );

    }
    else
    {

        # Run single worker
        Gearman::JobScheduler::Worker::run_worker( $gjs_config, $gearman_function_name_or_directory );
    }

}

main();