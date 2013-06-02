package WWW::Battie::DBI;
use strict;
use warnings;
use Carp qw(carp croak);
use base qw/ Class::Accessor::Fast Exporter /;
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/ handles /);
use WWW::Battie::DBH;

sub create {
    my ($class, $dsn) = @_;
    my $handles = {};
    for my $name (keys %$dsn) {
        my $ds = $dsn->{$name};
        my $dbh = WWW::Battie::DBH->create($ds);
        #$dbh->connect;
        $handles->{$name}->{dbh} = $dbh;
        $handles->{$name}->{storage} = undef;
        $handles->{$name}->{dsn} = [
            "dbi:$ds->{DBS}:host=$ds->{HOST};database=$ds->{DATABASE};port=$ds->{PORT}",
            $ds->{USER},
            $ds->{PASSWORD},
        ];
    }
    my $self = $class->new({
            handles => $handles,
            #dsn     => $ds,
        });
    return $self;
}

sub handle {
    my ($self, $name) = @_;
    my $handle = $self->get_handles->{$name}->{dbh};
    #warn __PACKAGE__." ********* get handle $name\n";
    #$handle->connect;
    return $handle;
}

sub get_dsn {
    my ($self, $name) = @_;
    my $dsn = $self->get_handles->{$name}->{dsn};
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$dsn], ['dsn']);
    return @$dsn;
}

sub storage {
    my ($self, $name, $storage) = @_;
    my $handle = $self->get_handles->{$name};
    if ($storage) {
        $handle->{storage} = $storage;
    }
    return $handle->{storage};
}

1;

=pod

=head1 NAME

WWW::Battie::DBI - DB Interface

=head FUNCTIONS

=over 4

=back

=cut
