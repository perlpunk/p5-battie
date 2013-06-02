package WWW::Battie::Schema::User::Profile;
use strict;
use warnings;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/
    TimeStamp PK::Auto InflateColumn::Serializer Core
/);
__PACKAGE__->table('user_profile');
__PACKAGE__->add_columns(
    user_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    name => {
        data_type => 'varchar',
        size      => '64',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
    },
    email => {
        data_type => 'varchar',
        size      => '128',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
    },
    homepage => {
        data_type => 'varchar',
        size      => '128',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
    },
    geo => {
        data_type => 'varchar',
        size      => '21',
        is_nullable => 1,
    },
    avatar => {
        data_type => 'varchar',
        size      => '37',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
    },
    location => {
        data_type => 'varchar',
        size      => '64',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
    },
    signature => {
        data_type         => 'text',
        size              => '',
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => undef,
    },
    sex => {
        data_type         => "ENUM('f','m','t')",
        size              => '',
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => undef,
    },
    icq => {
        data_type         => 'varchar',
        size              => 32,
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => undef,
    },
    aol => {
        data_type         => 'varchar',
        size              => 32,
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => undef,
    },
    yahoo => {
        data_type         => 'varchar',
        size              => 32,
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => undef,
    },
    msn => {
        data_type         => 'varchar',
        size              => 32,
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => undef,
    },
    interests => {
        data_type         => 'varchar',
        size              => 512,
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => undef,
    },
    foto_url => {
        data_type         => 'varchar',
        size              => 128,
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => undef,
    },
    birth_year => {
        data_type         => 'int',
        size              => 4,
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => undef,
    },
    birth_day => {
        data_type         => 'char',
        size              => 4,
        is_nullable       => 1,
        is_auto_increment => 0,
        default_value     => undef,
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
    meta => {
        data_type           => 'text',
        serializer_class    => 'JSON',
        is_nullable         => 1,
    },
);
__PACKAGE__->set_primary_key('user_id');
#__PACKAGE__->utf8_columns(qw/name email homepage location signature interests foto_url/);

my @acc = qw/
    user_id name email homepage location geo signature sex icq aol yahoo msn
    interests birth_year birth_day foto_url avatar ctime mtime meta
/;

sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Battie::Schema::User::Profile::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $value = $self->$field;
        if ($field eq 'birth_day') {
            my $bd = $self->birth_day;
            no warnings;
            my ($month, $day) = $bd =~ m/(\d\d)(\d\d)/;
            $value = $bd ? "$month/$day" : '';
        }
        $ro->$set( $value );
    }
    return $ro;
#            rendered_sig => undef,
}
1;
