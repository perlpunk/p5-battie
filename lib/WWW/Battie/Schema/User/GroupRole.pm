package WWW::Battie::Schema::User::GroupRole;
use strict;
use warnings;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('group_role');
__PACKAGE__->add_columns(
    group_id => {
        data_type   => 'int',
        size        => '10',
        is_nullable => 0,
    },
    role_id => {
        data_type   => 'int',
        size        => '10',
        is_nullable => 0,
    },
);
__PACKAGE__->set_primary_key(qw/ group_id role_id /);
__PACKAGE__->belongs_to('groups' => 'WWW::Battie::Schema::User::Group', 'group_id');
__PACKAGE__->belongs_to('roles' => 'WWW::Battie::Schema::User::Role', 'role_id');

my @acc = qw/ group_id role_id /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Battie::Schema::User::Profile::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $value = $self->$field;
        $ro->$set( $value );
    }
    return $ro;
}
1;
