package WWW::Poard::Model::Tag;
use strict;
use warnings;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ PK::Auto UTF8Columns Core /);
__PACKAGE__->table('poard_tag');
__PACKAGE__->add_columns(
    id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    name => {
        data_type => 'varchar',
        size      => '128',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->utf8_columns(qw/ name /);
__PACKAGE__->add_unique_constraint([qw/ name /]);
__PACKAGE__->has_many('thread_tags' => 'WWW::Poard::Model::ThreadTag', 'tag_id');

my @acc = qw/
    id name
/;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::Tag::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        $ro->$set($val);
    }
    return $ro;
}

1;
