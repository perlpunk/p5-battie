package WWW::Battie::Schema::User::Settings;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('user_settings');
__PACKAGE__->add_columns(
    user_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    messagecount => {
        data_type => 'bigint',
        size      => '15',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => 0,
    },
    # notify via email when got personal message
    send_notify => {
        data_type         => 'tinyint',
        size              => '1',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => 0,
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
__PACKAGE__->set_primary_key('user_id');
__PACKAGE__->belongs_to(user => 'WWW::Battie::Schema::User::User','user_id');

my @acc = qw/ user_id messagecount send_notify ctime mtime /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Battie::Schema::User::Settings::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        $ro->$set( $self->$field );
    }
    return $ro;
}

1;
