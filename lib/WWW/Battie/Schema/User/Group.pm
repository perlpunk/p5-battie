package WWW::Battie::Schema::User::Group;
use strict;
use warnings;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('group');
__PACKAGE__->add_columns(
    id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    name => {
        data_type         => 'varchar',
        size              => '64',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => '',
    },
    rtype => {
        data_type         => 'varchar',
        size              => '32',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => '',
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many('grouproles' => 'WWW::Battie::Schema::User::GroupRole', 'group_id');
__PACKAGE__->many_to_many('roles' => 'grouproles', 'group');
__PACKAGE__->has_many('users' => 'WWW::Battie::Schema::User::User', 'group_id');

my @acc = qw/ id name rtype /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Battie::Schema::User::Group::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $value = $self->$field;
        $ro->$set( $value );
    }
    return $ro;
}
1;
