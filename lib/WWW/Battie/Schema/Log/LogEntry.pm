package WWW::Battie::Schema::Log::LogEntry;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('log');
__PACKAGE__->add_columns(
    id => {
        data_type => 'bigint',
        size      => '21',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    user_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    module => {
        data_type => 'varchar',
        size      => '32',
        is_nullable => 0,
        is_auto_increment => 0,
        #default_value => ,
    },
    action => {
        data_type => 'varchar',
        size      => '64',
        is_nullable => 0,
        is_auto_increment => 0,
        #default_value => ,
    },
    object_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 1,
        is_auto_increment => 0,
        #default_value => ,
    },
    object_type => {
        data_type => 'varchar',
        size      => '64',
        is_nullable => 1,
        is_auto_increment => 0,
        #default_value => ,
    },
    ip => {
        data_type => 'varchar',
        size      => '16',
        is_nullable => 0,
        is_auto_increment => 0,
        #default_value => ,
    },
    country => {
        data_type   => 'char',
        size        => '2',
        is_nullable => 1,
    },
    city => {
        data_type   => 'varchar',
        size        => '32',
        is_nullable => 1,
    },
    forwarded_for => {
        data_type => 'varchar',
        size      => '128',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    comment => {
        data_type => 'varchar',
        size      => '256',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    referrer => {
        data_type => 'varchar',
        size      => '256',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->utf8_columns(qw/comment referrer/);

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Schema::Log::LogEntry::Readonly->new({
            id            => $self->id,
            user_id       => $self->user_id,
            module        => $self->module,
            action        => $self->action,
            object_id     => $self->object_id,
            object_type   => $self->object_type,
            ip            => $self->ip,
            country       => $self->country,
            city          => $self->city,
            forwarded_for => $self->forwarded_for,
            comment       => $self->comment,
            referrer      => $self->referrer,
            ctime         => $self->ctime,
            user          => undef,
        });
}

1;
