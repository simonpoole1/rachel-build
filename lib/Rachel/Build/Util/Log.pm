package Rachel::Build::Util::Log;

use strict;
use warnings;

use Carp;
use Log::Any::Adapter;
use Log::Log4perl qw(:easy);

my $SETUP_DONE = 0;

sub setup_logging {
    my $config_dir = $ENV{RACHEL_BUILD_CONFIG_DIR};
    confess "RACHEL_BUILD_CONFIG_DIR not installed by RachelPerlSetup"
        unless $config_dir;

    my $conf_file = File::Spec->catfile($config_dir, 'log4perl.conf');
    Log::Log4perl::init($conf_file);

    Log::Any::Adapter->set('Log4perl');
    return;
}

sub set_info_log_level {
    get_logger('')->level($INFO);
    return;
}

sub set_debug_log_level {
    get_logger('')->level($DEBUG);
    return;
}

1;
