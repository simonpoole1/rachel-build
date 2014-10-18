package Rachel::Build::Fetcher;

use strict;
use warnings;

use Carp;
use English qw(-no_match_vars);
use Readonly;

Readonly::Scalar my $RSYNC_EXE => '/usr/bin/rsync';
die "$RSYNC_EXE not found or not executable" unless -x $RSYNC_EXE;

Readonly::Scalar my $RSYNC_SOURCE => 'rsync://dev.worldpossible.org/rachelmods';
Readonly::Array my @EXCLUDE_PATTERNS => ('rachel*.zip');
Readonly::Array my @RSYNC_ARGS => (
    '-P',  # Keep partial files and show download progress
    '-i',  # Output a change summary for each file
    '-a',  # Archive mode (-rlptgoD)
    '-v',  # Verbose - list transferred files
    '-h',  # Human readable file sizes

    # Exclude some files that exist on the server but shouldn't be transferred
    map { "--exclude=$_" } @EXCLUDE_PATTERNS,
);

sub new {
    my ($class, %args) = @_;

    my $self = {};
    $self->{modules}   = $args{modules} // [];
    confess "No modules provided" unless @{$self->{modules}};

    $self->{cache_dir} = $args{cache_dir};
    confess "No cache dir provided" unless $args{cache_dir};
    confess "Cache dir does not exist or is not writable"
        unless -d $self->{cache_dir} && -w $self->{cache_dir};

    $self->{dry_run}   = $args{dry_run};

    return bless $self => $class;
}

sub fetch {
    my ($self) = @_;

    my @rsync_sources = map { "$RSYNC_SOURCE/$_" } @{$self->{modules}};

    my @cmd = $RSYNC_EXE;
    push @cmd, '-n' if $self->{dry_run};
    push @cmd, @RSYNC_ARGS, @rsync_sources, "$self->{cache_dir}/";
    print STDERR join(" ", map { "\"$_\"" } @cmd),"\n";

    # Execute the command
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

sub get_modules {
    my ($self) = @_;
    return [@{$self->{modules}}];
}
1;
