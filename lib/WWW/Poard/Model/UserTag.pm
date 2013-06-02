package WWW::Poard::Model::UserTag;
use strict;
use warnings;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('poard_user_tag');
__PACKAGE__->add_columns(
    tag_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
    },
    user_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key(qw/ tag_id user_id /);
__PACKAGE__->belongs_to('tag' => 'WWW::Poard::Model::Tag', 'tag_id');

my @acc = qw/
    tag_id user_id ctime
/;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::UserTag::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        $ro->$set($val);
    }
    return $ro;
}

1;
