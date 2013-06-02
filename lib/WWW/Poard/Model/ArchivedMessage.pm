package WWW::Poard::Model::ArchivedMessage;
use strict;
use warnings;
use base qw/ DBIx::Class /;

__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('poard_archived_message');
 __PACKAGE__->resultset_class('WWW::Poard::Resultset::Message');
__PACKAGE__->add_columns(
    id => {
        data_type           => 'bigint',
        size                => '20',
        is_nullable         => 0,
        is_auto_increment   => 1,
    },
    msg_id => {
        data_type       => 'bigint',
        size            => '20',
        is_nullable     => 0,
    },
    lasteditor_id => {
        data_type       => 'bigint',
        size            => '20',
        is_nullable     => 1,
    },
    thread_id => {
        data_type       => 'bigint',
        size            => '20',
        is_nullable     => 0,
    },
    message => {
        data_type       => 'text',
        size            => '',
        is_nullable     => 1,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
);
__PACKAGE__->utf8_columns(qw/ message /);
__PACKAGE__->set_primary_key(qw/ id /);

my @acc = qw/
    id msg_id thread_id message lasteditor_id ctime
/;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::ArchivedMessage::Readonly->new({
        is_editable => 0,
    });
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        $ro->$set($val);
    }
    return $ro;
}

1;
