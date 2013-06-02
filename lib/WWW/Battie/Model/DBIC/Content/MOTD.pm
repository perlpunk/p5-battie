package WWW::Battie::Model::DBIC::Content::MOTD;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('content_motd');
__PACKAGE__->add_columns(
    id => {
        data_type           => 'int',
        size                => '10',
        is_nullable         => 0,
        is_auto_increment   => 1,
    },
    weight => {
        data_type           => 'int',
        size                => '4',
        is_nullable         => 0,
    },
    content => {
        data_type   => 'text',
        size        => '',
        is_nullable => 1,
    },
    start => {
        data_type => 'datetime',
    },
    end => {
        data_type => 'datetime',
    },
);
__PACKAGE__->set_primary_key('id');
#__PACKAGE__->utf8_columns(qw/ content /);

my @acc = qw/ id weight content start end /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Battie::Model::DBIC::Content::MOTD::Readonly->new({
    });
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        $ro->$set($val);
    }
    return $ro;

}

1;
