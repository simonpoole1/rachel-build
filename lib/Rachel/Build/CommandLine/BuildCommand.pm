package Rachel::Build::CommandLine::BuildCommand;

use Moose;
use namespace::autoclean;
with 'Rachel::Build::CommandLine::Command';

use Carp;
use Cwd qw(abs_path);
use English qw(-no_match_vars);
use File::Spec;
use File::Temp;
use Getopt::Long;
use IPC::System::Simple qw(run);
use Log::Any qw($log);
use Readonly;

use Rachel::Build::Fetchers::RachelModuleFetcher;
use Rachel::Build::Util::Log;

has 'modules'    => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'cache_dir'  => ( is => 'ro', isa => 'Str',      required => 1 );
has 'build_type' => ( is => 'ro', isa => 'Str',      required => 1 );
has 'output'     => ( is => 'ro', isa => 'Str',      required => 1 );
has 'base_image' => ( is => 'ro', isa => 'Str');
has 'dry_run'    => ( is => 'ro', isa => 'Bool' );

Readonly::Hash my %BUILDERS => (
    pi64 => {
        description => "Raspberry PI 64GB build, including Raspbian OS",
        constructor => \&_construct_pi64_builder,
        base_image_required => 1,
    },
    pi32 => {
        description => "Raspberry PI 32GB build, including Raspbian OS",
        constructor => \&_construct_pi32_builder,
        base_image_required => 1,
    },
## Not implemented yet:
#    content => {
#        description => "Content-only build",
#        constructor => \&_construct_content_only_builder,
#    },
#    wamp => {
#        description => "WAMP build including Windows webserver etc",
#        constructor => \&_construct_wamp_builder,
#    },
);

################################################################################

sub get_usage {
    my $usage = <<"USAGE";
Usage:  $0 build [options]

Options:
    -t, --type=BUILD_TYPE  See below for available build types. [required]
    -o, --output=DEST      Output destination.  The output format is
                           automatically derived from the filename.  If it ends
                           in ".img" a disk image will be created. If it ends
                           in ".tar", ".tar.gz" or ".tgz" a tarball will be
                           created.  Otherwise a directory will be created.
                           [required]
    -c, --cache-dir=DIR    Location of local content cache [required]
    -m, --module=MODULE    Module or module set to include in fetch. Can be
                           specified multiple times, or with a comma-separated
                           list. [required]
    -n, --dry-run          Output what would be done, but don't actually do it.
    -b, --base=FILE        Base image to use when creating disk images. E.g.
                           the pi build requires a Raspbian image file.
    -v, --verbose          Verbose logging

Build types:
USAGE

    foreach my $builder (sort keys %BUILDERS) {
        $usage .= sprintf("    %-12s%s\n", $builder,
            $BUILDERS{$builder}{description});
    }
    return $usage;
}

sub build_from_command_line {
    my ($class) = @_;

    my ($build_type, $output, $cache_dir, @modules, $base_image,
        $dry_run, $verbose, $help);
    Getopt::Long::Configure ("bundling");
    GetOptions(
        "t|type=s"       => \$build_type,
        "o|output=s"     => \$output,
        "c|cache-dir=s"  => \$cache_dir,
        "m|module=s@"    => \@modules,
        "b|base=s"       => \$base_image,
        "n|dry-run"      => \$dry_run,
        "v|verbose"      => \$verbose,
        "h|help|?"       => \$help,
    ) || $class->invocation_error("Invalid command-line args");

    $class->usage if $help;
    Rachel::Build::Util::Log::set_debug_log_level() if $verbose;

    $class->invocation_error("No build type provided") unless $build_type;
    my $builder = $BUILDERS{$build_type};
    $class->invocation_error("Unrecognised build type: $build_type")
        unless $builder;

    $class->invocation_error("No output provided") unless $output;
    # TODO: validate output string

    if ($builder->{base_image_required}) {
        $class->invocation_error(
            "Base image required for $build_type builds, but not provided")
            unless $base_image;
        $class->invocation_error(
            "Base image not found or not readable: $base_image")
            unless -r $base_image;
    }

    return $class->new(
        build_type => $build_type,
        output     => $output,
        modules    => $class->process_module_options(\@modules),
        cache_dir  => $class->process_cache_dir_option($cache_dir),
        base_image => $base_image,
        dry_run    => $dry_run,
    );
}

sub run_command {
    my ($self) = @_;

    my $build_dir = $self->_create_temporary_build_dir;
    $log->info("Building in $build_dir");

    # Prepare content to install, using a symlink tree
    $log->info("Building content tree");
    my $content_dir = File::Spec->catdir($build_dir, 'rachelmod');
    $self->_build_content_tree($content_dir);

    # Build the relevant image
    my $builder_config = $BUILDERS{$self->build_type};
    confess "Invalid builder: $self->build_type" unless $builder_config;
    # Note - stringify $build_dir to a filename so that it passes validation,
    # but retain our own reference so that the temp dir doesn't get
    # automatically cleaned up.
    my $builder = $builder_config->{constructor}->($self, "$build_dir");
    $builder->build($content_dir);
    return;
}

################################################################################

sub _construct_pi64_builder {
    my ($self, $build_dir) = @_;

    require Rachel::Build::Builders::PiBuilder;
    my $builder = Rachel::Build::Builders::PiBuilder->new(
        base_image  => $self->base_image,
        dry_run     => $self->dry_run,
        build_dir   => $build_dir,
        size        => 64 * 1024 * 1024 * 1024,
        output_file => $self->output,
    );
    return $builder;
}

sub _construct_pi32_builder {
    my ($self, $build_dir) = @_;

    require Rachel::Build::Builders::PiBuilder;
    my $builder = Rachel::Build::Builders::PiBuilder->new(
        base_image  => $self->base_image,
        dry_run     => $self->dry_run,
        build_dir   => $build_dir,
        size        => 32 * 1024 * 1024 * 1024,
        output_file => $self->output,
    );
    return $builder;
}

sub _build_content_tree {
    my ($self, $build_dir) = @_;

    # Ensure trailing slash on build_dir
    $build_dir =~ s{/?$}{/};

    # Symlink all of the module content into our content tree
    foreach my $module (@{$self->modules}) {
        my $module_dir = abs_path(
            File::Spec->catdir($self->cache_dir, $module));
        my @cmd = ('cp', '-as', $module_dir, $build_dir);
        $log->debug(join(" ", map { "\"$_\"" } @cmd));

        run(@cmd);
    }
    return;
}

sub _create_temporary_build_dir {
    my ($self) = @_;

    # Temporary directory is automatically deleted when this object is no
    # longer referenced.
    my $dir = File::Temp->newdir('build-XXXX',
        DIR => $self->_get_top_level_build_dir,
        #  CLEANUP => 0,  # uncomment to stop temp directory being deleted
    );

    return $dir;
}

sub _get_top_level_build_dir {
    my ($self) = @_;
    if ($ENV{RACHEL_BUILD_DIR}) {
        my $dir = abs_path($ENV{RACHEL_BUILD_DIR});
        die "$ENV{RACHEL_BUILD_DIR} (in \$RACHEL_BUILD_DIR) doesn't exist"
            unless $dir && -e $dir;
        die "$ENV{RACHEL_BUILD_DIR} (in \$RACHEL_BUILD_DIR) is not a directory"
            unless -d $dir;
        die "$ENV{RACHEL_BUILD_DIR} (in \$RACHEL_BUILD_DIR) is not writeable"
            unless -w $dir;
        return $dir;
    } else {
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
}

 __PACKAGE__->meta->make_immutable;
1;
