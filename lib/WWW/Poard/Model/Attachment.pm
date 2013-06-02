package WWW::Poard::Model::Attachment;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns InflateColumn::Serializer Core /);
__PACKAGE__->table('poard_attachment');
__PACKAGE__->add_columns(
    message_id => {
        data_type   => 'bigint',
        size        => '20',
        is_nullable => 0,
    },
    attach_id => {
        data_type       => 'int',
        size            => '10',
        is_nullable     => 0,
    },
    type => {
        data_type       => 'varchar',
        size            => '32',
        is_nullable     => 0,
    },
    filename => {
        data_type       => 'varchar',
        size            => '32',
        is_nullable     => 0,
    },
    meta => {
        data_type       => 'varchar',
        size            => '256',
        is_nullable     => 0,
        serializer_class => 'JSON',
    },
    size => {
        data_type       => 'int',
        size            => '10',
        is_nullable     => 0,
    },
    deleted => {
        data_type       => 'int',
        size            => '1',
        is_nullable     => 0,
        default_value   => 0,
    },
    thumb => {
        data_type       => 'int',
        size            => '1',
        is_nullable     => 0,
        default_value   => 0,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
    mtime => {
        data_type     => 'datetime',
        set_on_create => 1,
        set_on_update => 1,
    },
);
__PACKAGE__->set_primary_key(qw/ message_id attach_id /);
__PACKAGE__->utf8_columns(qw/ meta filename /);
__PACKAGE__->belongs_to(message => 'WWW::Poard::Model::Message','message_id');

my @acc = qw/
    message_id attach_id type filename meta size deleted thumb ctime mtime
/;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::Attachment::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        $ro->$set($val);
    }
    return $ro;
}

1;
