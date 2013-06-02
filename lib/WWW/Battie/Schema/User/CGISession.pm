package WWW::Battie::Schema::User::CGISession;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('sessions');
__PACKAGE__->add_columns(
    id => {
        data_type => 'varchar',
        size      => '32',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    a_session => {
        data_type => 'text',
        size      => '',
        is_nullable => 0,
        is_auto_increment => 0,
        #default_value => '0',
    },
    mtime => {
        data_type   => 'datetime',
        is_nullable => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->utf8_columns(qw/ a_session /);

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Schema::User::CGISession::Readonly->new({
            id        => $self->id,
            a_session => $self->a_session,
            mtime     => $self->mtime,
        });
}

1;
