package WWW::Battie::Module::Model;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw(schema));
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(schema));
use base 'WWW::Battie::Module';

sub load_db {
    my ($self, $battie, @names) = @_;
    my %models = $self->model;
    my $schema = $self->schema;
    my $db = $battie->get_db;
    # if @names, only load given names, otherwise all
    for my $name (@names ? @names : keys %models) {
        if ($schema and $schema->{$name}) {
            next;
        }
        my $model = $models{$name};
        #warn __PACKAGE__." load_db() USING model $model $name\n";
        eval "use $model ()";
        if ($@) {
            warn "model: $@";
        }
    }
    #$self->set_schema($schema);
}

sub init_db {
    my ($self, $battie, @names) = @_;
    my %models = $self->model;
    my $schema = $self->schema;
    my $db = $battie->get_db;
    for my $name (@names ? @names : keys %models) {
        if ($schema and $schema->{$name}) {
            next;
        }
        my $model = $models{$name};
        my $handle_name = $battie->handle($model);
        my $handle = $db->handle($handle_name);
        #warn __PACKAGE__." USING model $model\n";
        eval "use $model ()";
        if ($@) {
            warn "model: $@";
        }
        $model->load_classes_once;
        my @dsn = $db->get_dsn($handle_name);
#        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@dsn], ['dsn']);
        if (my $storage = $db->storage($handle_name)) {
            $schema->{$name} = $model->clone;
            $schema->{$name}->storage($storage);
        }
        else {
            $schema->{$name} = $model->connect(
                @dsn,
    #            sub { $handle->get_handle },
                {
                    on_connect_do => [
#                "SET sql_mode='STRICT_TRANS_TABLES,STRICT_ALL_TABLES'",
                    ],
                    mysql_enable_utf8 => 1,
                    AutoCommit => 1,
                    # has to be 0 otherwise a begin_work dies after a
                    # connection timeout. let DBIC handle it
                    mysql_auto_reconnect => 0,
                },
            );
            $db->storage($handle_name, $schema->{$name}->storage);
        }

        my @sources = $schema->{$name}->sources;
        my $prefix = $battie->table_prefix($model);
        for my $source (@sources) {
            my $rsource = $schema->{$name}->source($source);
            my $original = $rsource->name;
            $rsource->name($prefix . '_' .$original);
        }
    }
    $self->set_schema($schema);
}




1;
