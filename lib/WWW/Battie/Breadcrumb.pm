package WWW::Battie::Breadcrumb;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use Moose;

with 'WWW::Battie::Object';

has 'crumbs' => (is => 'rw', isa => 'ArrayRef');

sub append {
    my ($self, $title, $link) = @_;
    my $crumbs = $self->crumbs || [];
    push @$crumbs, { title => $title, url => $link };
    $self->crumbs($crumbs);
    return $self;
}

sub pop {
    my $crumbs = $_[0]->crumbs;
    pop @$crumbs;
}

1;

