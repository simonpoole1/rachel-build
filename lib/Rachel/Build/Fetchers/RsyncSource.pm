package Rachel::Build::Fetchers::RsyncSource;

use Moose;
use namespace::autoclean;

use English qw(-no_match_vars);
use IPC::System::Simple qw(run);
use Log::Any qw($log);
use Readonly;

Readonly::Scalar my $RSYNC_EXE => '/usr/bin/rsync';
die "$RSYNC_EXE not found or not executable" unless -x $RSYNC_EXE;

Readonly::Array my @RSYNC_ARGS => (
    '-P',  # Keep partial files and show download progress
    '-i',  # Output a change summary for each file
    '-a',  # Archive mode (-rlptgoD)
    '-v',  # Verbose - list transferred files
    '-h',  # Human readable file sizes
);

################################################################################

has 'sources'     => ( is => 'ro', isa => 'ArrayRef[Str]', required => 1 );
has 'destination' => ( is => 'ro', isa => 'Str', required => 1 );
has 'exclude_patterns'
                  => ( is => 'ro', isa => 'ArrayRef[Str]' );
has 'dry_run'     => ( is => 'ro', isa => 'Bool' );

################################################################################

sub fetch {
    my ($self, %args) = @_;

    my @cmd = ($RSYNC_EXE, @RSYNC_ARGS);
    push @cmd, '-n' if $self->dry_run;

    my $exclude = $self->exclude_patterns;
    push @cmd, map { "--exclude=$_" } @$exclude
        if $exclude && @$exclude;

    push @cmd, @{$self->{sources}}, $self->{destination};

    $log->debug(join(" ", map { "\"$_\"" } @cmd));

    # Execute the command
    # TODO: redirect stdout
    run(@cmd);
    return;
 }

__PACKAGE__->meta->make_immutable;
1;
