package Rachel::Build::Util::DiskImage;

use strict;
use warnings;

use Carp;
use IPC::System::Simple qw(run capture);
use Log::Any qw($log);
use Scope::Guard qw(guard);

sub extend_image {
    my ($image_file, $desired_size) = @_;

    # TODO: check that the desired size is greater than the current size.

    # Sparsely resize the image file.  It does this without consuming any extra
    # physical space on the disk, so it happens instantly.
    $log->debug("Extending disk image");
    run('truncate', '-c', '-s', $desired_size, $image_file);

    # Resize the last partition in the image by deleting and then recreating
    # it.  This doesn't affect the actual filesystem and, because the new
    # partition starts in exactly the same place as the old one, nothing is
    # lost.
    $log->debug("Finding partition");
    my $partitions = list_partitions($image_file);
    my $last_partition = $partitions->[-1];

    croak "Resizing a non-primary partition isn't currently supported"
        unless $last_partition->{num} < 5;
    croak "Unsupported partition type '".$last_partition->{fs_type}
        ."' - expecting ext2/3/4"
        unless $last_partition->{fs_type} =~ m/^ext[234]$/;
    $log->debug("Deleting partition $last_partition->{num}");
    run('parted', '-s', $image_file, 'rm', $last_partition->{num});
    $log->debug("Creating partition $last_partition->{num}");
    run('parted', '-s', $image_file, 'mkpart', 'primary',
        "$last_partition->{start}B", '100%');

    # Resize the filesystem.  An fsck is required first.  Running resize2fs
    # without any size options tells it to extend the filesystem to fill the
    # partition.
    setup_loopback_and_run($image_file, sub {
        my ($device) = @_;

        my $partition = "${device}p$last_partition->{num}";
        confess "Failed to discover partition $partition" unless -e $partition;

        $log->debug("Checking filesystem on $partition");
        run('sudo', 'e2fsck', '-f', $partition);
        $log->debug("Resizing filesystem on $partition");
        run('sudo', 'resize2fs', $partition);
    });
    return;
}

sub list_partitions {
    my ($image_file) = @_;
    my $output = capture('parted', '-s', '-m', $image_file,
        'unit', 'B', 'print');

    # Example output:
    #    WARNING: You are not superuser.  Watch out for permissions.
    #    BYT;
    #    /media/simon/RACHEL/build/manual/output.img:64424509440B:file:512:512:msdos:;
    #    1:4194304B:62914559B:58720256B:fat16::lba;
    #    2:62914560B:3276799999B:3213885440B:ext4::;

    my @partitions;

    foreach my $line (split /\n/, $output) {
        my ($partition, $start, $end, $size, $fs_type)
            = ($line =~ m/^(\d+):(\d+)B:(\d+)B:(\d+)B:([^:]+):/);
        next unless $partition;

        push @partitions, {
            num     => $partition,
            start   => $start,
            end     => $end,
            size    => $size,
            fs_type => $fs_type,
        }
    }

    return \@partitions;
}

sub setup_loopback_and_run {
    my ($image_file, $coderef) = @_;

    $log->debug("Setting up loopback device");
    my $device = capture('sudo', 'losetup', '-f', '--show', $image_file);
    chomp $device;
    confess "Failed to set up loopback device" unless $device;

    # Automatically clean up when we exit this scope
    my $losetup_cleanup = guard {
        $log->debug("Removing loopback device");
        run('sudo', 'losetup', '-d', $device);
    };

    $log->debug("Discovering partitions for $device");
    run('sudo', 'partprobe', $device);

    $coderef->($device);

    return;
}

sub mount_partition_and_run {
    my ($image_file, $partition_num, $mount_dir, $coderef) = @_;

    setup_loopback_and_run($image_file, sub {
        my ($device) = @_;

        $log->debug("Mounting disk image");
        my $partition = "${device}p${partition_num}";
        run('sudo', 'mount', '-o', 'loop,rw', $partition, $mount_dir);

        # Automatically clean up when we exit this scope
        my $mount_guard = guard {
            $log->debug("Unmounting disk image");
            run('sudo', 'umount', $mount_dir);
        };

        $coderef->();
    });
    return;
}

sub mount_last_partition_and_run {
    my ($image_file, $mount_dir, $coderef) = @_;

    my $partitions = list_partitions($image_file);
    my $last_partition = $partitions->[-1];

    mount_partition_and_run($image_file, $last_partition->{num},
        $mount_dir, $coderef);
    return;
}
1;
