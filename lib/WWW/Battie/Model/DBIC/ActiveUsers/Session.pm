package WWW::Battie::Model::DBIC::ActiveUsers::Session;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ PK::Auto InflateColumn::Serializer Core /);
__PACKAGE__->table('au_session');
__PACKAGE__->add_columns(
    id => {
        data_type   => 'char',
        size        => '64',
        is_nullable => 0,
    },
    user_id => {
        data_type   => 'bigint',
        size        => 20,
        is_nullable => 1,
    },
    data => {
        data_type           => 'text',
        serializer_class    => 'JSON',
        is_nullable         => 1,
    },
    ctime => {
        data_type     => 'int',
        size          => 11,
        default_value => 0,
    },
    mtime => {
        data_type     => 'int',
        size          => 11,
        default_value => 0,
    },
    expires => {
        data_type     => 'int',
        size          => 11,
        default_value => 0,
    },
);
__PACKAGE__->set_primary_key('id');

my @acc = (qw/ id user_id data ctime mtime expires /);
sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Model::DBIC::ActiveUsers::Session::Readonly->new({
            map { ( $_ => $self->$_ ) } @acc
        });
    return $ro;
}

1;
