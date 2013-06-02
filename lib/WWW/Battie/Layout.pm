package WWW::Battie::Layout;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(elements default));

sub from_ini {
    my ($class, $battie, $args) = @_;
    my $elements = {};
    my $default = '';
    for my $name (keys %$args) {
        my $ini = $args->{$name};
        if ($ini->{DEFAULT}) {
            $default = $name;
        }
        $elements->{$name} = [split m/;/, $ini->{ELEMENTS} || ''];
    }
    my $self = $class->new({
        elements => $elements,
        default => $default,
    });
}

1;
