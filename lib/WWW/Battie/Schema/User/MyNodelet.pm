package WWW::Battie::Schema::User::MyNodelet;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ PK::Auto UTF8Columns Core /);
__PACKAGE__->table('user_my_nodelet');
__PACKAGE__->add_columns(
    user_id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    content => {
        data_type     => 'text',
        is_nullable   => 0,
    },
    is_open => {
        data_type     => 'tinyint',
        size          => '1',
        is_nullable   => 0,
        default_value => '1',
    },
);
__PACKAGE__->set_primary_key('user_id');
__PACKAGE__->utf8_columns(qw/ content /);

sub readonly {
    my ($self, $select) = @_;
    my $fields = {
        user_id    => $self->user_id,
        content    => $self->content,
        is_open    => $self->is_open,
    };
    my $selected = {};
    if ($select) {
        @$selected{ @$select } = @$fields{ @$select };
    }
    else {
        $selected = $fields;
    }
    my $ro = WWW::Battie::Schema::User::MyNodelet::Readonly->new($selected);
}
1;
