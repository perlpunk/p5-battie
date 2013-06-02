package WWW::Poard::Model::Trash;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('poard_trash');
__PACKAGE__->add_columns(
    id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    thread_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
    },
    msid => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
    },
    deleted_by => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
    },
    comment => {
        data_type => 'varchar',
        size      => '64',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
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
#__PACKAGE__->belongs_to('user', 'WWW::Battie::Schema::User::User', 'deleted_by');

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Poard::Model::Trash::Readonly->new({
            id         => $self->id,
            thread_id  => $self->thread_id,
            msid       => $self->msid,
            comment    => $self->comment,
            deleted_by => $self->deleted_by,
            ctime      => $self->ctime,
            mtime      => $self->ctime ne $self->mtime ? $self->mtime : undef,
            board      => undef,
            user       => undef,
            message    => undef,
            thread     => undef,
        });
}


1;
