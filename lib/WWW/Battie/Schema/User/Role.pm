package WWW::Battie::Schema::User::Role;
use strict;
use warnings;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('role');
__PACKAGE__->add_columns(
    id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    name => {
        data_type         => 'varchar',
        size              => '32',
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
__PACKAGE__->has_many('actions' => 'WWW::Battie::Schema::User::RoleAction', 'role_id');
__PACKAGE__->has_many('userroles' => 'WWW::Battie::Schema::User::UserRole', 'role_id');
__PACKAGE__->many_to_many('users' => 'userroles', 'user');

sub readonly {
    my ($self, $select) = @_;
    my $fields = {
        id     => $self->id,
        name   => $self->name,
        rtype  => $self->rtype,
    };
    my $selected = {};
    if ($select) {
        @$selected{ @$select } = @$fields{ @$select };
    }
    else {
        $selected = $fields;
    }
    my $ro = WWW::Battie::Schema::User::Role::Readonly->new($selected);
}

1;
