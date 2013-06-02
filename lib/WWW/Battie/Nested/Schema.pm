package WWW::Battie::Nested::Schema;
use strict;
use warnings;
use Carp qw(carp croak);
#use base 'Class::Accessor::Fast';
#__PACKAGE__->follow_best_practice;
#__PACKAGE__->mk_accessors(qw/ lft rgt /);

sub is_leaf {
    $_[0]->lft + 1 == $_[0]->rgt
}
sub is_root { $_[0]->lft == 1 }


1;
