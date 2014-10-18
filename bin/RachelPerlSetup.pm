package RachelPerlSetup;

# Minimum of Perl 5.10 so that we have the "//" operator
use 5.010_000;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;

sub add_libs_to_perl_path {
    my $bin_dir = dirname(__FILE__);
    my $lib_dir = File::Spec->catdir($bin_dir, File::Spec->updir, 'lib');
    unshift @INC, abs_path($lib_dir);
    return;
}

BEGIN {
    add_libs_to_perl_path();
}

1;
