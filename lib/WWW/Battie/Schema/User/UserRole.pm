package WWW::Battie::Schema::User::UserRole;
use strict;
use warnings;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('user_role');
__PACKAGE__->add_columns(
    role_id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    user_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    mtime => {
        data_type     => 'datetime',
        set_on_create => 1,
        set_on_update => 1,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key(qw(role_id user_id));
__PACKAGE__->belongs_to('user' => 'WWW::Battie::Schema::User::User', 'user_id');
__PACKAGE__->belongs_to('role' => 'WWW::Battie::Schema::User::Role', 'role_id');

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Schema::User::UserRole::Readonly->new({
            user_id => $self->user_id,
            role_id => $self->role_id,
            ctime => $self->ctime,
            mtime => $self->mtime,
        });
}

1;
