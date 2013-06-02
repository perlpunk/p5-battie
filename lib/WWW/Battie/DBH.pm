package WWW::Battie::DBH;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(dbs handle database host port socket user password));
use DBI;

sub create {
    my ($class, $ds) = @_;
    my $self = $class->new({
            database => $ds->{DATABASE},
            dbs  => $ds->{DBS},
            $ds->{HOST} ?
            (
                port => $ds->{PORT},
                host => $ds->{HOST},
            ) :
            (
                socket => $ds->{SOCKET},
            ),
            user => $ds->{USER},
            password => $ds->{PASSWORD},
        });
    return $self;
}

sub connect {
    my ($self) = @_;
    my $dbh = $self->get_handle;
    #warn __PACKAGE__." already connected\n" if $dbh and $dbh->ping;
    return $dbh if $dbh and $dbh->ping;
    #sleep 1;
    my $host = $self->get_host;
    my $db = $self->get_database;
    my $user = $self->get_user;
    my $pass = $self->get_password;
    my $dbs = $self->get_dbs || 'mysql';
    my $dsn;
    if ($host) {
        #warn __PACKAGE__." connect $host\n";
        my $port = $self->get_port || '';
        $port = ";port=$port" if length $port;
        $dsn = "dbi:$dbs:host=$host$port;database=$db";
    }
    else {
        my $socket = $self->get_socket;
        $dsn = "dbi:$dbs:mysql_socket=$socket;database=$db";
    }
    #warn __PACKAGE__.':'.__LINE__.": connect to DSN $dsn\n";
    $dbh = DBI->connect($dsn,$user,$pass)
        or croak "Could not connect to database: ".DBI->errstr;
    #warn __PACKAGE__." connected $host\n";
    $self->set_handle($dbh);
}

1;
