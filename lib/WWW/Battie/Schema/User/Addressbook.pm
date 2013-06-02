package WWW::Battie::Schema::User::Addressbook;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('user_abook');
__PACKAGE__->add_columns(
    user_id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    contactid => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    note => {
        data_type         => 'varchar',
        size              => '128',
        is_nullable       => 1,
        is_auto_increment => 0,
    },
    # blacklist user ? 1 : 0
    blacklist => {
        data_type         => 'tinyint',
        size              => 1,
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => 0,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
);
__PACKAGE__->utf8_columns(qw/note/);
__PACKAGE__->set_primary_key(qw(user_id contactid));
__PACKAGE__->belongs_to(user => 'WWW::Battie::Schema::User::User','user_id');
__PACKAGE__->belongs_to(contact => 'WWW::Battie::Schema::User::User','contactid');

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Schema::User::Addressbook::Readonly->new({
            user_id    => $self->user_id,
            contactid => $self->contactid,
            note      => $self->note,
            blacklist => $self->blacklist,
            ctime     => $self->ctime,
            user      => undef,
            contact   => undef,
        });
}

1;
