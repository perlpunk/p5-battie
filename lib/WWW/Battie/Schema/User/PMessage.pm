package WWW::Battie::Schema::User::PMessage;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('pm');
__PACKAGE__->add_columns(
    id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    sender => {
        data_type => 'int',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    message => {
        data_type => 'text',
        size      => '',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    subject => {
        data_type => 'varchar',
        size      => '128',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    recipients => {
        data_type => 'varchar',
        size      => 128,
        is_nullable => 0,
        is_auto_increment => 0,
    },
    has_read => {
        data_type => 'tinyint',
        size      => 1,
        is_nullable => 0,
        is_auto_increment => 0,
    },
    copy_of => {
        data_type => 'bigint',
        size      => 20,
        is_nullable => 0,
        is_auto_increment => 0,
    },
    box_id => {
        data_type => 'int',
        size      => 10,
        is_nullable => 0,
        is_auto_increment => 0,
    },
    sent_notify => {
        data_type         => 'tinyint',
        size              => 1,
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => 1,
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
__PACKAGE__->belongs_to(box => 'WWW::Battie::Schema::User::Postbox','box_id');
#__PACKAGE__->belongs_to(sender_user => 'WWW::Battie::Schema::User::User','sender');
__PACKAGE__->has_many('recipients' => 'WWW::Battie::Schema::User::MessageRecipient', 'message_id');

my @acc = qw/ id sender message subject recipients has_read copy_of
box_id sent_notify ctime mtime /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Battie::Schema::User::PMessage::Readonly->new({
        });
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $value = $self->$field;
        $ro->$set( $value );
    }
	return $ro;
}

1;
