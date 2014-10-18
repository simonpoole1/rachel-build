package Rachel::Build::CommandLine::Command;

# Abstract base-class/interface for the command-line commands
use Moose::Role;
use namespace::autoclean;

use Rachel::Build::ModuleConfig;

requires 'get_usage';
requires 'build_from_command_line';
requires 'run';

sub invocation_error {
    my ($class, $err, $show_usage) = @_;
    print STDERR $err, "\n";
    print STDERR "\n",$class->get_usage() if $show_usage;
    print STDERR "\n";
    exit 1;
}

sub usage {
    my ($class) = @_;
    print $class->get_usage(), "\n";
    exit 0;
}

sub process_module_options {
    my ($class, $modules) = @_;

    # Process modules list, which may be a mixture of modules, module sets,
    # and modules to exclude (prefixed with "-"), possibly comma-separated
    my @modules = split(/,/, join(',', @$modules));
    my ($known, $unknown)
        = Rachel::Build::ModuleConfig::expand_module_list(@modules);
    if ($unknown && @$unknown) {
        $class->invocation_error("Unrecognized modules: " . join(", ", @$unknown)
            . "\n" . "For a list of available modules try '$0 list'");
    }
    $class->invocation_error("No modules provided", 1) unless $known && @$known;
    return $known;
}

sub process_cache_dir_option {
    my ($class, $cache_dir) = @_;

    $class->invocation_error("No cache dir supplied", 1) unless $cache_dir;
    $class->invocation_error("Cache dir does not exist: $cache_dir")
        unless -d $cache_dir;
    $class->invocation_error("Cache dir is not writable: $cache_dir")
        unless -w $cache_dir;
    # strip trailing slash if present
    $cache_dir =~ s/[\/\\]$//;
    return $cache_dir;
}

1;
