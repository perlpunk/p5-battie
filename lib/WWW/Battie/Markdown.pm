package WWW::Battie::Markdown;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use base 'Class::Accessor::Fast';
my @acc = qw(
    markdown battie
);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);

1;

__END__

=pod

=head1 NAME

Foo::Bar

=cut

