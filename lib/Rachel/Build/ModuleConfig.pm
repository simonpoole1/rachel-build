package Rachel::Build::ModuleConfig;

use strict;
use warnings;

use Readonly;

Readonly::Hash my %MODULE_SETS => (
    # English modules
    "all-en" => [qw(
        ck12 ebooks hesperian iicba ka MathExpression med musictheory
        olpc powertyping scratch understanding_algebra wikip
    )],

    # Spanish modules
    "all-es" => [qw(
        ebooks-es guatemala-es hesperian-es ka-es medlineplus-es
        soluciones-es vedoque-es kiwix-es
    )],
    
    # Portuguese modules
    "all-pt" => [qw(
        ka-pt kiwix-pt
    )],
);

#-------------------------------------------
# Here we reorganize the grouped modules above into
# a single flat hash - this makes our command line 
# processing easier.
#-------------------------------------------
Readonly::Array my @ALL_MODULES => map { @$_ } values %MODULE_SETS;
Readonly::Hash  my %ALL_MODULES => map { $_ => 1 } @ALL_MODULES;

sub list_available_modules {
    my $list = "";
    foreach my $set (sort { lc $a cmp lc $b } keys %MODULE_SETS) {
        $list .= "\t$set\n";
        foreach my $mod (sort { lc $a cmp lc $b } @{$MODULE_SETS{$set}}) {
            $list .= "\t\t$mod\n";
        }
    }
    return $list;
}

sub expand_module_list {
    my (@module_list) = @_;

    my (%get, %dontget, %unknown);

    foreach my $mod (@module_list) {
        # load in a module set
        if ($MODULE_SETS{$mod}) {
            $get{$_} = 1 foreach @{$MODULE_SETS{$mod}};

        # add a single module to our list
        } elsif ($ALL_MODULES{$mod}) {
            $get{$mod} = 1;

        # detect "-", add those to the don't get list
        } elsif ($mod =~ /^\-/ and $ALL_MODULES{ substr($mod, 1) }) {
            $dontget{ substr($mod, 1) } = 1;

        # stuff we don't recognize
        } else {
            $mod =~ s/^\-//;
            $unknown{$mod} = 1;
        }
    }

    delete $get{$_} foreach keys %dontget;

    return (
        [ sort { lc $a cmp lc $b } keys %get ],
        [ sort { lc $a cmp lc $b } keys %unknown ],
    );
}




