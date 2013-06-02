package WWW::Battie::Nested;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/ lft rgt /);

sub is_leaf {
    $_[0]->get_lft + 1 == $_[0]->get_rgt
}
sub is_root { $_[0]->get_lft == 1 }

sub children_count {
    return ($_[0]->rgt - $_[0]->lft - 1) / 2
}

sub children_count_incl {
    return ($_[0]->rgt - $_[0]->lft - 1) / 2 + 1
}

1;
