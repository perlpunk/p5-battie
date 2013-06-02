package WWW::Battie::Schema::System::TermUser;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('system_term_user');
__PACKAGE__->add_columns(
    term_id => {
        data_type	=> 'char',
        size		=> '32',
        is_nullable => 0,
    },
    user_id => {
        data_type	=> 'int',
        size		=> '20',
        is_nullable => 0,
    },
	start_date => {
		data_type => 'datetime',
	},
);
__PACKAGE__->set_primary_key(qw/ term_id start_date user_id /);

my @acc = qw/ term_id start_date user_id /;
sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Schema::System::TermUser::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        $ro->$set($val);
    }
	return $ro;
}

1;
