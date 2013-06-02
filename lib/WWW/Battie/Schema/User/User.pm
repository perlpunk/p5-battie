package WWW::Battie::Schema::User::User;
use strict;
use warnings;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('poard_user');
__PACKAGE__->add_columns(
    id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    group_id => {
        data_type   => 'int',
        size        => '10',
        is_nullable => 0,
        default_value => '0',
    },
    extra_roles => {
        data_type => 'tinyint',
        size      => '1',
        is_nullable => 0,
        default_value => '0',
    },
    active => {
        data_type => 'tinyint',
        size      => '1',
        is_nullable => 0,
        default_value => '0',
    },
    nick => {
        data_type => 'varchar',
        size      => '64',
        is_nullable => 0,
        default_value => '',
    },
    password => {
        data_type => 'varchar',
        size      => '32',
        is_nullable => 0,
        default_value => '',
    },
    mtime => {
        data_type     => 'datetime',
        set_on_create => 1,
        set_on_update => 1,
    },
    lastlogin => {
        data_type => 'datetime',
        size      => '',
        is_nullable => 1,
    },
    openid => {
        data_type => 'varchar',
        size      => '16',
        is_nullable => 1,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->might_have(profile => 'WWW::Battie::Schema::User::Profile');
__PACKAGE__->might_have(settings => 'WWW::Battie::Schema::User::Settings');
__PACKAGE__->might_have(group => 'WWW::Battie::Schema::User::Group');
__PACKAGE__->has_many('userroles' => 'WWW::Battie::Schema::User::UserRole', 'user_id');
__PACKAGE__->many_to_many('roles' => 'userroles', 'role');
__PACKAGE__->add_unique_constraint([qw/ nick /]);


sub readonly {
    my ($self, $select) = @_;
    my $fields = {
        id       => $self->id,
        active   => $self->active,
        nick     => $self->nick,
        password => undef,
        ctime    => $self->ctime,
        mtime    => $self->mtime,
        lastlogin => $self->lastlogin,
        openid    => $self->openid,
        settings => undef,
        profile  => undef,
        visible  => undef,
        group_id => $self->group_id,
        extra_roles => $self->extra_roles,
    };
    my $selected = {};
    if ($select) {
        @$selected{ @$select } = @$fields{ @$select };
        if (exists $selected->{password}) {
            $selected->{password} = $self->password;
        }
    }
    else {
        $selected = $fields;
    }
    my $ro = WWW::Battie::Schema::User::User::Readonly->new($selected);
}

sub get_password { shift->password }
sub set_password {
    my ($self, $pass) = @_;
    my $crypted = crypt($pass, ["A".."Z"]->[rand 26] . ["A".."Z"]->[rand 26]);
    $self->password($crypted)
}
sub get_id { shift->id }

1;
