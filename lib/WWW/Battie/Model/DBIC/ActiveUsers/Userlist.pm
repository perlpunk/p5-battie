package WWW::Battie::Model::DBIC::ActiveUsers::Userlist;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('user_list');
__PACKAGE__->add_columns(
    user_id => {
        data_type => 'int',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    last_seen => {
        data_type   => 'datetime',
        is_nullable => 1,
        set_on_create => 1,
        set_on_update => 1,
    },
    logged_in => {
        data_type     => 'datetime',
        is_nullable   => 0,
    },
    visible => {
        data_type => 'int',
        size      => '1',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => 1,
    },
);
__PACKAGE__->set_primary_key('user_id');

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Model::DBIC::ActiveUsers::Userlist::Readonly->new({
						user_id => $self->user_id,
						last_seen => $self->last_seen,
						logged_in => $self->logged_in,
						visible => $self->visible,
        });
}

package WWW::Battie::Model::DBIC::ActiveUsers::Userlist::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(user_id last_seen logged_in visible);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_ro_accessors(@acc);

1;
