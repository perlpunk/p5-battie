package WWW::Battie::Search::Date;
use strict;
use warnings;
use Data::Dumper;

use base qw/ KinoSearch::FieldType /;
no warnings 'redefine';

sub analyzed     { 0 }
sub indexed      { 1 }
sub stored       { 1 }
sub analyzed     { 0 }
sub vectorized   { 0 }
sub binary       { 0 }
sub compressed   { 0 }

1;
