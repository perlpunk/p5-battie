package WWW::Battie::Accessor;
use strict;
use warnings;
use base 'Class::Accessor::Fast';

{
    no strict 'refs';
    sub follow_good_practice {
        my($self) = @_;
        my $class = ref $self || $self;
        *{"${class}::accessor_name_for"}  = \&Class::Accessor::accessor_name_for;
        *{"${class}::mutator_name_for"}  = \&Class::Accessor::best_practice_mutator_name_for;
    }
}

sub create_bits {
    my ($class, %args) = @_;
    my $var = $class . "::_bits";
    no strict 'refs';
    my %hash;
    for my $key (%args) {
        $class->mk_accessors($key);
        my $names = $args{$key};
        for my $i (0 .. $#$names) {
            my $name = $names->[$i];
            $hash{ $name } = [$i, $key];
            my $dec = 2**$i;
            my $getter = sub {
                return $_[0]->$key & $dec;
            };
            my $set = "set_$key";
            my $setter = sub {
                my ($self, $value) = @_;
                #warn __PACKAGE__.':'.__LINE__.": set_$key $value '| $dec'\n";
                if ($value) {
                    $self->$set($self->$key | $dec);
                }
                else {
                    $self->$set($self->$key - $dec) if $self->$key & $dec;
                }
                return $self->$key;
            };
            *{ $class . "::get_bit_$name" } = $getter;
            *{ $class . "::set_bit_$name" } = $setter;
        }
    }
    *{ $var } = \%hash;
}

1;
