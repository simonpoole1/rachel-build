package Rachel::Build::CommandLine::Command;

# Abstract base-class/interface for the command-line commands
use Moose::Role;
use namespace::autoclean;

use Rachel::Build::ModuleConfig;

requires 'get_usage';
requires 'build_from_command_line';
requires 'run';

sub usage {
    my ($class, $err) = @_;
    my $fh = $err ? \*STDERR : \*STDOUT;
    print $fh "\nError: $err\n\n" if $err;
    print $fh $class->get_usage(),"\n";
    exit 1;
}

sub process_module_options {
    my ($class, $modules) = @_;

    # Process modules list, which may be a mixture of modules, module sets,
    # and modules to exclude (prefixed with "-"), possibly comma-separated
    my @modules = split(/,/, join(',', @$modules));
    my ($known, $unknown) = Rachel::Build::ModuleConfig::expand_module_list(@modules);
    if ($unknown && @$unknown) {
        die "Unrecognized modules: " . join(", ", @$unknown) . "\n"
          . "For a list of available modules try '$0 list'\n";
    }
    $class->usage("No modules provided") unless $known && @$known;
    return $known;
}

sub process_cache_dir_option {
    my ($class, $cache_dir) = @_;

    $class->usage("No cache dir supplied") unless $cache_dir;
    die("Cache dir does not exist: $cache_dir") unless -d $cache_dir;
    die("Cache dir is not writable: $cache_dir") unless -w $cache_dir;
    # strip trailing slash if present
    $cache_dir =~ s/[\/\\]$//;
    return $cache_dir;
}

1;
