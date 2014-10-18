package Rachel::Build::Fetchers::RachelModuleFetcher;

use Moose;
use namespace::autoclean;
extends 'Rachel::Build::Fetchers::Fetcher';

use Carp;
use English qw(-no_match_vars);
use Log::Any qw($log);
use Readonly;

use Rachel::Build::Fetchers::RsyncSource;

################################################################################

Readonly::Scalar my $RSYNC_SOURCE => 'rsync://dev.worldpossible.org/rachelmods';
Readonly::Array my @EXCLUDE_PATTERNS => ('rachel*.zip');

has 'modules'   => ( is => 'ro', isa => 'ArrayRef[Str]', required => 1 );
has 'cache_dir' => ( is => 'ro', isa => 'Str', required => 1 );
has 'dry_run'   => ( is => 'ro', isa => 'Bool' );

sub BUILD {
    my ($self) = @_;
    confess "No modules provided" unless @{$self->modules};

    confess "No cache dir provided" unless $self->cache_dir;
    confess "Cache dir does not exist or is not writable"
        unless -d $self->cache_dir && -w $self->cache_dir;

    return;
}

################################################################################

sub fetch {
    my ($self) = @_;

    foreach my $module (@{$self->modules}) {
        $log->info("Fetching module: $module");
        my $rsync = Rachel::Build::Fetchers::RsyncSource->new(
            sources          => [ "$RSYNC_SOURCE/$module" ],
            destination      => $self->cache_dir.'/',
            exclude_patterns => \@EXCLUDE_PATTERNS,
            dry_run          => $self->dry_run,
        );
        $rsync->fetch;
        $log->info("Finished fetching module: $module");
    }

    return;
}

__PACKAGE__->meta->make_immutable;
1;
