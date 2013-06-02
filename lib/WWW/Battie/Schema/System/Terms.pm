package WWW::Battie::Schema::System::Terms;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('system_terms');
__PACKAGE__->add_columns(
    id => {
        data_type	=> 'char',
        size		=> '32',
        is_nullable => 0,
    },
    name => {
        data_type	=> 'varchar',
        size		=> '128',
        is_nullable => 0,
    },
    style => {
        data_type	=> 'varchar',
        size		=> '16',
        is_nullable => 0,
    },
    content => {
        data_type	=> 'text',
        is_nullable => 1,
    },
	start_date => {
		data_type => 'datetime',
	},
);
__PACKAGE__->set_primary_key(qw/ id start_date /);

my @acc = qw/ id name content start_date style /;
sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Schema::System::Terms::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        $ro->$set($val);
    }
	return $ro;
}

1;
