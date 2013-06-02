package WWW::Battie::Schema::User::ActionToken;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('action_token');
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 1,
    },
    user_id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => '0',
    },
    token => {
        data_type         => 'varchar',
        size              => '32',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    action => {
        data_type         => 'varchar',
        size              => '32',
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => '',
    },
    info => {
        data_type         => 'text',
        size              => '',
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => '',
    },
    mtime => {
        data_type     => 'datetime',
        set_on_create => 1,
        set_on_update => 1,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->utf8_columns(qw/info/);

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Schema::User::ActionToken::Readonly->new({
            id      => $self->id,
            user_id => $self->user_id,
            token   => $self->token,
            action  => $self->action,
            info    => $self->info,
            ctime   => $self->ctime,
            mtime   => $self->mtime,
        });
}

1;
