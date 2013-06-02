package WWW::Battie::Object;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);

use Moose::Role;

sub dumper {
    my ($self) = @_;
    my @caller = caller();
    warn $caller[0].':'.$caller[2].$".Data::Dumper->Dump([\$self], ['object']);
}

1;
