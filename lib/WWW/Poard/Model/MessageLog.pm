package WWW::Poard::Model::MessageLog;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('poard_msglog');
__PACKAGE__->add_columns(
    message_id => {
        data_type   => 'bigint',
        size        => '20',
        is_nullable => 0,
    },
    log_id => {
        data_type       => 'int',
        size            => '10',
        is_nullable     => 0,
    },
    action => {
        data_type       => 'varchar',
        size            => '64',
        is_nullable     => 0,
    },
    comment => {
        data_type       => 'varchar',
        size            => '256',
        is_nullable     => 1,
    },
    user_id => {
        data_type       => 'int',
        size            => '20',
        is_nullable     => 0,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key(qw/ message_id log_id /);
__PACKAGE__->utf8_columns(qw/ comment /);
__PACKAGE__->belongs_to(message => 'WWW::Poard::Model::Message','message_id');

my @acc = qw/
    message_id log_id action comment user_id ctime
/;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::MessageLog::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        $ro->$set($val);
    }
    return $ro;
}

1;
