package WWW::Battie::Schema::User::Token;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('token');
__PACKAGE__->add_columns(
    id => {
        data_type => 'varchar',
        size      => '32',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    id2 => {
        data_type => 'varchar',
        size      => '32',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    user_id => {
        data_type => 'int',
        size      => '20',
        is_nullable => 1,
        is_auto_increment => 0,
        default_value => '0',
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

my @acc = qw/ id id2 user_id ctime mtime /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Battie::Schema::User::Token::Readonly->new({
#            id      => $self->id,
#            id2     => $self->id2,
#            user_id => $self->user_id,
#            ctime   => $self->ctime,
#            mtime   => $self->mtime,
        });
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $value = $self->$field;
        $ro->$set( $value );
    }
	return $ro;
}

1;
