package WWW::Battie::Textile;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use base 'Text::Textile';

sub new {
    my ($class, %args) = @_;
    my $self_url = delete $args{self_url};
    my $content_url = delete $args{content_url};
    my $textile = $class->SUPER::new(%args);
    $textile->{_battie}->{self_url} = $self_url;
    $textile->{_battie}->{content_url} = $content_url;
    return $textile;
}

sub format_link {
    my ($self, %args) = @_;
    if ($args{url} =~ m/^battie:(.*)\Z/) {
        $args{url} = $self->{_battie}->{self_url} . $1;
    }
    elsif ($args{url} =~ m/^content:(.*)\Z/) {
        $args{url} = $self->{_battie}->{content_url} . $1;
    }
    return $self->SUPER::format_link(%args);
}

sub format_image {
    my ($self, %args) = @_;
    if ($args{src} =~ m/^content:(.*)\Z/) {
        $args{src} = $self->{_battie}->{content_url} . $1;
    }
    return $self->SUPER::format_image(%args);
}

1;
