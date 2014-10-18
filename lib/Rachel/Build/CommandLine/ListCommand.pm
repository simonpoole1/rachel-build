package Rachel::Build::CommandLine::ListCommand;

use Moose;
use namespace::autoclean;
with 'Rachel::Build::CommandLine::Command';

use Getopt::Long;

use Rachel::Build::ModuleConfig;

################################################################################

sub get_usage {
    return <<"EOF";
Usage:  $0 list
EOF
}

sub build_from_command_line {
    my ($class) = @_;

    my $help;
    GetOptions(
        "h|help|?"       => \$help,
    ) || $class->invocation_error("Invalid command-line args", 1);

    $class->usage if $help;

    return $class->new();
}

sub run {
    print "Available modules:\n",
        Rachel::Build::ModuleConfig::list_available_modules(),
        "\n";
}

__PACKAGE__->meta->make_immutable;
1;
