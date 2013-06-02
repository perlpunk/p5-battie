package WWW::Battie::Sorter;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use base 'Class::Accessor::Fast';
my @acc = qw(
    fields sort param uri sort_fields max_sort
);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_wo_accessors(@acc);

sub to_template {
    my ($self) = @_;
    my $sort = $self->sort || [];
    my $param = '';
    my $uri = $self->uri;
    my %sort_fields;
    for my $opt (@$sort) {
        my $field = $opt->{field};
        my $order = $opt->{order} || 'A';
        $param .= '-' if $param;
        $param .= "$field$order";
        $sort_fields{$field} = {
            name => $field,
            asc => $order eq 'A',
            desc => $order eq 'D',
        },
    }
    my $fields = $self->fields;
    for my $field (@$fields) {
        unless ($sort_fields{$field}) {
            $sort_fields{$field} = {
                name => $field,
            };
        }
    }
    $uri =~ s/%s/$param/g;
    $sort_fields{$_}->{uri} = $uri for keys %sort_fields;
    $self->set_sort_fields(\%sort_fields);
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%sort_fields], ['sort_fields']);
    $self->set_param($param);
}

sub from_cgi {
    my ($class, $args) = @_;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$args], ['args']);
    my $cgi = $args->{cgi};
    my $new_sort = $args->{new};
    my $uri = $args->{uri};
    my $fields = $args->{fields} || [];
    my %allowed = map { $_ => 1 } @$fields;
    $cgi ||= '';
    my $max_sort = $args->{max_sort} || scalar @$fields;
    my @opts = split /-/, $cgi;
    my @options;
    for my $opt (@opts) {
        my ($field, $order) = $opt =~ m/^([a-z_0-9]+)([AD]*)\z/;
        next if (!$field or !$allowed{$field});
        $order ||= 'A';
        push @options, {
            field => $field,
            order => $order,
        };
    }
    if ($new_sort) {
        my ($field, $order) = $new_sort =~ m/^([a-z_0-9]+)-([AD0]+)\z/;
        if ($allowed{$field}) {
            $order ||= 0;
            $order = 0 if $order !~ m/^[AD]\z/;
            my $found;
            if ($order eq 0) {
                # delete existing sort
                @options = grep { $_->{field} ne $field } @options;
                $found = 1;
            }
            else {
                for my $opt (@options) {
                    if ($opt->{field} eq $field) {
                        $opt->{order} = $order;
                        $found = 1;
                        last;
                    }
                }
            }
            unless ($found) {
                push @options, {
                    field => $field,
                    order => $order,
                };
            }
        }
    }
    if ($max_sort < @options) {
        splice @options, 0, (@options - $max_sort);
    }
    my $self = $class->new({
            fields => $fields,
            sort => \@options,
            uri => $uri,
            max_sort => $max_sort,
        });
    return $self;
}

1;
