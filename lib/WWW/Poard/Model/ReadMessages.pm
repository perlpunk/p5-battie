package WWW::Poard::Model::ReadMessages;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto InflateColumn::Serializer Core /);
__PACKAGE__->table('poard_read_messages');
__PACKAGE__->add_columns(
    thread_id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => '0',
    },
    user_id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => '0',
    },
    position => {
        data_type         => 'int',
        size              => '10',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => '0',
    },
    mtime => {
        data_type     => 'datetime',
#        set_on_create => 1,
#        set_on_update => 1,
    },
    meta => {
        data_type           => 'text',
        serializer_class    => 'JSON',
        is_nullable         => 1,
    },
);
__PACKAGE__->set_primary_key(qw/user_id thread_id/);
__PACKAGE__->belongs_to(thread => 'WWW::Poard::Model::Thread','thread_id');
#__PACKAGE__->utf8_columns(qw/ meta /);

my @acc = qw/ thread_id user_id position mtime meta /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::ReadMessages::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        $ro->$set($val);
    }
    $ro->set_mtime_epoch($self->mtime->epoch);
    return $ro;
}

1;
