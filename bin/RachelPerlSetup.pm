package RachelPerlSetup;

# Minimum of Perl 5.10 so that we have the "//" operator
use 5.010_000;
use strict;
use warnings;

use Cwd qw(abs_path);
use English qw(-no_match_vars);
use File::Basename qw(dirname);
use File::Spec;
use Log::Any::Adapter;
use Log::Log4perl qw(:easy);

my $RACHEL_BUILD_ROOT_DIR;

my $SETUP_DONE = 0;

################################################################################

sub _set_up_environment {
    my $bin_dir = dirname(__FILE__);

    my $root_dir = abs_path(File::Spec->catdir($bin_dir, File::Spec->updir));
    $ENV{RACHEL_BUILD_ROOT_DIR} = $root_dir;

    my $conf_dir = abs_path(File::Spec->catdir($root_dir, 'config'));
    $ENV{RACHEL_BUILD_CONFIG_DIR} = $conf_dir;
    return;
}

sub _add_libs_to_perl_path {
    my $lib_dir = File::Spec->catdir($ENV{RACHEL_BUILD_ROOT_DIR}, 'lib');
    unshift @INC, abs_path($lib_dir);
    return;
}

BEGIN {
    if (!$SETUP_DONE) {
        $SETUP_DONE = 1;
        _set_up_environment();
        _add_libs_to_perl_path();

        require Rachel::Build::Util::Log;
        Rachel::Build::Util::Log::setup_logging();
    }
}

1;
