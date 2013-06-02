package WWW::Battie::Schema;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);

my $SQL_CALC_FOUND_ROWS = 0;
sub count_search {
    my ($self, $name, $cond, $opts) = @_;
    my %opts = %{ $opts || {} };
    if ($SQL_CALC_FOUND_ROWS) {
        unless (exists $opts{select}) {
            #my @cols = map { "me.$_" } $self->source($name)->columns;
            my @cols = map { "$_" } $self->source($name)->columns;
            my $first = shift @cols;
            $opts{as} = [$first, @cols];
            #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%opts], ['opts']);
            $first = "SQL_CALC_FOUND_ROWS $first";
            $opts{select} = [$first, @cols];
        }
        my $rs = $self->resultset($name);
        my $dbh = $self->source($name)->storage->dbh;
        my $search = $rs->search(
            $cond,
            { %opts },
        );
        my $count = sub { ($dbh->selectrow_array("select found_rows()"))[0] };
        return ($search, $count);
    }
    else {
        my $rs = $self->resultset($name);
        my $number = $rs->count( $cond );
        my $count = sub { return $number };
        my $search = $rs->search(
            $cond,
            $opts,
        );
        return ($search, $count);
    }
}

sub select_path {
    my ($self, $name, $id) = @_;
    my $rs = $self->resultset($name);
    my $class = $rs->result_class;
    my $r = $class->select_path($rs, $id);
    return $r;
}

sub select_children {
    my ($self, $name, $id) = @_;
    my $rs = $self->resultset($name);
    my $class = $rs->result_class;
    my @r = $class->select_children($rs, $id);
    return @r;
}

sub insert_node {
    my ($self, $name, $id, $data) = @_;
    my $rs = $self->resultset($name);
    my $class = $rs->result_class;
    my $node = $class->insert_node($rs, $id, $data);
    return $node;
}

sub delete_node {
    my ($self, $name, $id) = @_;
    my $rs = $self->resultset($name);
    my $class = $rs->result_class;
    my $deleted = $class->delete_node($rs, $id);
    return $deleted;
}

sub set {
    my ($self, $name, $func, @args) = @_;
    my $rs = $self->resultset($name);
    my $class = $rs->result_class;
    return $class->$func($rs, @args);
}

1;

__END__

