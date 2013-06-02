package WWW::Battie::Schema::User::Postbox;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('postbox');
__PACKAGE__->add_columns(
    id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    user_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    name => {
        data_type => 'varchar',
        size      => 64,
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
    },
    type => {
        data_type => "ENUM('in','out')",
        size      => '',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => 'in',
    },
    is_default => {
        data_type => 'tinyint',
        size      => 1,
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => 0,
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
__PACKAGE__->has_many('messages' => 'WWW::Battie::Schema::User::PMessage', 'box_id');
__PACKAGE__->belongs_to(user => 'WWW::Battie::Schema::User::User','user_id');

my @acc = qw/ id user_id name type is_default ctime mtime /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Battie::Schema::User::Postbox::Readonly->new({
        });
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $value = $self->$field;
        $ro->$set( $value );
    }
	return $ro;
}

1;
