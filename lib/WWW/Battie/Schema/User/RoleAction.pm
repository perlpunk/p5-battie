package WWW::Battie::Schema::User::RoleAction;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('role_action');
__PACKAGE__->add_columns(
    id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    role_id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    action => {
        data_type => 'varchar',
        size      => '128',
        is_nullable => 0,
        is_auto_increment => 0,
    },
#    mtime => {
#        data_type     => 'datetime',
#        set_on_create => 1,
#        set_on_update => 1,
#    },
#    ctime => {
#        data_type     => 'datetime',
#        set_on_create => 1,
#    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(role => 'WWW::Battie::Schema::User::Role','role_id');

sub readonly {
    my ($self, $select) = @_;
    my $fields = {
        id => $self->id,
        role_id => $self->role_id,
        action => $self->action,
        role => undef,
    };
    my $selected = {};
    if ($select) {
        @$selected{ @$select } = @$fields{ @$select };
    }
    else {
        $selected = $fields;
    }
    my $ro = WWW::Battie::Schema::User::RoleAction::Readonly->new($selected);
}

1;
