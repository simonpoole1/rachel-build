package RachelPerlSetup;

# Minimum of Perl 5.10 so that we have the "//" operator
use 5.010_000;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;
use Log::Any::Adapter;
use Log::Log4perl qw(:easy);

my $RACHEL_BUILD_ROOT_DIR;

################################################################################

sub set_info_log_level {
    get_logger('')->level($INFO);
}

sub set_debug_log_level {
    get_logger('')->level($DEBUG);
}

################################################################################

sub _find_root_dir {
    my $bin_dir = dirname(__FILE__);
    return abs_path(File::Spec->catdir($bin_dir, File::Spec->updir));
}

sub _add_libs_to_perl_path {
    my $lib_dir = File::Spec->catdir($RACHEL_BUILD_ROOT_DIR, 'lib');
    unshift @INC, abs_path($lib_dir);
    return;
}

sub _setup_logging {
    my $conf_file = File::Spec->catfile(
        $RACHEL_BUILD_ROOT_DIR, 'config', 'log4perl.conf');
    Log::Log4perl::init($conf_file);
    Log::Any::Adapter->set('Log4perl');
}

BEGIN {
    $RACHEL_BUILD_ROOT_DIR = _find_root_dir();
    _add_libs_to_perl_path();
    _setup_logging();
}

1;
