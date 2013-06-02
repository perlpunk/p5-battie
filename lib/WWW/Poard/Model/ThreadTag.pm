package WWW::Poard::Model::ThreadTag;
use strict;
use warnings;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ PK::Auto Core /);
__PACKAGE__->table('poard_thread_tag');
__PACKAGE__->add_columns(
    tag_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
    },
    thread_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
    },
);
__PACKAGE__->set_primary_key(qw/ tag_id thread_id /);
__PACKAGE__->belongs_to('tag' => 'WWW::Poard::Model::Tag', 'tag_id');
__PACKAGE__->belongs_to('thread' => 'WWW::Poard::Model::Thread', 'thread_id');

my @acc = qw/
    tag_id thread_id
/;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::ThreadTag::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        $ro->$set($val);
    }
    return $ro;
}

1;
