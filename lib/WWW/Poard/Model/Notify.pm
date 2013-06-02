package WWW::Poard::Model::Notify;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('poard_notify');
__PACKAGE__->add_columns(
    id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    user_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    thread_id => {
        data_type   => 'bigint',
        size        => '20',
        is_nullable => 0,
    },
    msg_id => {
        data_type   => 'bigint',
        size        => '20',
        is_nullable => 1,
    },
    last_notified => {
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
__PACKAGE__->add_unique_constraint([qw(user_id thread_id)]);
__PACKAGE__->belongs_to(thread => 'WWW::Poard::Model::Thread','thread_id');

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Poard::Model::Trash::Readonly->new({
            id            => $self->id,
            user_id       => $self->user_id,
            thread_id     => $self->thread_id,
            msg_id        => $self->msg_id,
            last_notified => $self->last_notified,
            ctime         => $self->ctime,
            thread        => undef,
        });
}


1;
