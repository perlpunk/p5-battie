package WWW::Battie::Schema::User::NewUser;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns InflateColumn::Serializer Core /);
__PACKAGE__->table('users_new_user');
__PACKAGE__->add_columns(
    id => {
        data_type           => 'bigint',
        size                => '20',
        is_nullable         => 0,
        is_auto_increment   => 1,
    },
    token => {
        data_type           => 'varchar',
        size                => '32',
        is_nullable         => 0,
    },
    email => {
        data_type       => 'varchar',
        size            => '128',
        is_nullable     => 0,
        default_value   => '',
    },
    nick => {
        data_type       => 'varchar',
        size            => '64',
        is_nullable     => 0,
        default_value   => '',
    },
    password => {
        data_type       => 'varchar',
        size            => '32',
        is_nullable     => 0,
        default_value   => '',
    },
    openid => {
        data_type   => 'varchar',
        size        => '16',
        is_nullable => 1,
    },
    meta => {
        data_type           => 'text',
        serializer_class    => 'JSON',
        is_nullable         => 1,
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
__PACKAGE__->set_primary_key('id');
__PACKAGE__->utf8_columns(qw/ email nick meta /);
__PACKAGE__->add_unique_constraint([qw/ nick /]);

sub readonly {
    my ($self, $select) = @_;
    my $fields = {
        id          => $self->id,
        token       => $self->token,
        email       => $self->email,
        nick        => $self->nick,
        password    => undef,
        openid      => $self->openid,
        meta        => $self->meta,
        ctime       => $self->ctime,
        mtime       => $self->mtime,
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
    my $ro = WWW::Battie::Schema::User::NewUser::Readonly->new($selected);
}

sub set_password {
    my ($self, $pass) = @_;
    my $crypted = crypt($pass, ["A".."Z"]->[rand 26] . ["A".."Z"]->[rand 26]);
    $self->password($crypted)
}

1;
