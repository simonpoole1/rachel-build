package Rachel::Build::Builders::PiBuilder;

use Moose;
use namespace::autoclean;

use Carp;
use English qw(-no_match_vars);
use File::Copy;
use File::Spec;
use IPC::System::Simple qw(run);
use Log::Any qw($log);

use Rachel::Build::Util::DiskImage;

has 'build_dir'   => ( is => 'ro', isa => 'Str', required => 1 );
has 'base_image'  => ( is => 'ro', isa => 'Str', required => 1 );
has 'size'        => ( is => 'ro', isa => 'Int', required => 1 );
has 'output_file' => ( is => 'ro', isa => 'Str', required => 1 );
has 'dry_run'     => ( is => 'ro', isa => 'Bool' );

sub BUILD {
    my ($self) = @_;

    my $base_image = $self->base_image;
    croak "Required base image was not provided"
        unless $self->base_image;
    croak "Base image not found or not readable: ",$self->base_image
        unless -r $self->base_image;
    return;
}

################################################################################

sub build {
    my ($self, $content_dir) = @_;

#    my $output_file = File::Spec->catfile($self->build_dir, 'output.img');
    my $output_file = $self->output_file;

    # Clone the base image file.  We use the system "cp" command rather than
    # Perl's File::Copy because we want to create a sparse copy if possible
    # (where runs of zeroes don't occupy physical space on disk).
    # TODO: Provide an option to update or overwrite the output file
    if (!-e $output_file) {
        $log->info("Cloning base image ",$self->base_image);
        run('cp', '--sparse=always', $self->base_image, $output_file)
            unless $self->dry_run;
    }

    # Resize it to the required size
    $log->info("Resizing ".$self->base_image." to ".$self->size." bytes");
    Rachel::Build::Util::DiskImage::extend_image($output_file, $self->size)
        unless $self->dry_run;

    # Copy the content into place
    $log->info("Installing content");
    if (!$self->dry_run) {
        my $mount_dir = File::Spec->catdir($self->build_dir, 'mnt');
        mkdir $mount_dir;
        Rachel::Build::Util::DiskImage::mount_last_partition_and_run(
            $output_file, $mount_dir,
            sub { $self->_install_content($content_dir, $mount_dir) }
        );
    }

    return;
}

sub _install_content {
    my ($self, $content_dir, $mount_dir) = @_;

    my $www_dir = File::Spec->catfile($mount_dir, 'var', 'www');
    run('sudo', 'rsync', '--copy-unsafe-links', '-Pah', "$content_dir/", $www_dir);
    return;
}

sub _get_top_level_build_dir {
    my ($self) = @_;
    my $root = $ENV{RACHEL_BUILD_ROOT_DIR};
    confess "RACHEL_BUILD_ROOT_DIR not initialised by RachelPerlSetup"
        unless $root && -d $root;

    my $build_dir = abs_path(File::Spec->catdir($root, 'build'));
    if (!-e $build_dir) {
        mkdir $build_dir
            || die "Failed to create build dir $build_dir: $OS_ERROR";
    }
    die "Build dir $build_dir is not a directory or not writable"
        unless -d $build_dir && -w $build_dir;
    return $build_dir;
}


 __PACKAGE__->meta->make_immutable;
1;
