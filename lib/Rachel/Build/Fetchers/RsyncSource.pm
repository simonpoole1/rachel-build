package Rachel::Build::Fetchers::RsyncSource;

use Moose;
use namespace::autoclean;

use English qw(-no_match_vars);
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
    my $ret = system(@cmd);
    if ($ret) {
        my $err = $CHILD_ERROR;
        if ($CHILD_ERROR == -1) {
            confess "Failed to execute $RSYNC_EXE";
        } elsif ($CHILD_ERROR & 127) {
            die sprintf('rsync died with signal %d', $RSYNC_EXE, ($CHILD_ERROR & 127));
        } else {
            die sprintf('rsync exited with value %d', ($CHILD_ERROR >> 8));
        }
    }
    return;
 }

__PACKAGE__->meta->make_immutable;
1;
