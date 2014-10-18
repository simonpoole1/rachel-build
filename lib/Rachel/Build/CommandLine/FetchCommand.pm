package Rachel::Build::CommandLine::FetchCommand;

use Moose;
use namespace::autoclean;
with 'Rachel::Build::CommandLine::Command';

use Carp;
use Getopt::Long;
use Readonly;

use Rachel::Build::Fetcher;

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
EOF
}

sub build_from_command_line {
    my ($class) = @_;

    my ($cache_dir, @modules, $dry_run, $help);
    GetOptions(
        "c|cache-dir=s"  => \$cache_dir,
        "m|module=s@"    => \@modules,
        "n|dry-run"      => \$dry_run,
        "h|help|?"       => \$help,
    ) || $class->usage("Invalid command-line args");

    $class->usage if $help;

    return $class->new(
        modules   => $class->process_module_options(\@modules),
        cache_dir => $class->process_cache_dir_option($cache_dir),
        dry_run   => $dry_run,
    );
}

sub run {
    my ($self) = @_;

    print STDERR "Fetching modules: " . join(", ", @{$self->modules})."\n";
    my $fetcher = Rachel::Build::Fetcher->new(
        modules   => $self->modules,
        cache_dir => $self->cache_dir,
        dry_run   => $self->dry_run,
    );
    $fetcher->fetch();
    return;
}

__PACKAGE__->meta->make_immutable;
1;
