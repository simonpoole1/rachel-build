package Rachel::Build::CommandLine::FetchCommand;

use Moose;
use namespace::autoclean;
with 'Rachel::Build::CommandLine::Command';

use Carp;
use Getopt::Long;
use Log::Any qw($log);
use Readonly;

use Rachel::Build::Fetchers::RachelModuleFetcher;

has 'modules'   => ( is => 'ro', isa => 'ArrayRef[Str]' );
has 'cache_dir' => ( is => 'ro', isa => 'Str' );
has 'dry_run'   => ( is => 'ro', isa => 'Bool' );

################################################################################

sub get_usage {
    return <<"EOF";
Usage:  $0 fetch [options]

Options:
    -c, --cache-dir=DIR    Location of local content cache [required]
    -m, --module=MODULE    Module or module set to include in fetch. Can be
                           specified multiple times, or with a comma-separated
                           list. [required]
    -n, --dry-run          Output what would be done, but don't actually do it.
    -v, --verbose          Verbose logging
EOF
}

sub build_from_command_line {
    my ($class) = @_;

    my ($cache_dir, @modules, $dry_run, $help, $verbose);
    GetOptions(
        "c|cache-dir=s"  => \$cache_dir,
        "m|module=s@"    => \@modules,
        "n|dry-run"      => \$dry_run,
        "v|verbose"      => \$verbose,
        "h|help|?"       => \$help,
    ) || $class->invocation_error("Invalid command-line args", 1);

    $class->usage if $help;
    Rachel::Build::Util::Log::set_debug_log_level() if $verbose;

    return $class->new(
        modules   => $class->process_module_options(\@modules),
        cache_dir => $class->process_cache_dir_option($cache_dir),
        dry_run   => $dry_run,
    );
}

sub run_command {
    my ($self) = @_;

    my $fetcher = Rachel::Build::Fetchers::RachelModuleFetcher->new(
        modules   => $self->modules,
        cache_dir => $self->cache_dir,
        dry_run   => $self->dry_run,
    );
    $fetcher->fetch();
    return;
}

__PACKAGE__->meta->make_immutable;
1;
