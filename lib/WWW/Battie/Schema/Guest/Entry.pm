package WWW::Battie::Schema::Guest::Entry;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('guest_book_entry');
__PACKAGE__->add_columns(
    id => {
        data_type => 'bigint',
        size      => '21',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    name => {
        data_type => 'varchar',
        size      => '64',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    email => {
        data_type => 'varchar',
        size      => '128',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    url => {
        data_type => 'varchar',
        size      => '128',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    location => {
        data_type => 'varchar',
        size      => '64',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    message => {
        data_type => 'text',
        size      => '',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    comment => {
        data_type => 'text',
        size      => '',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    comment_by => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    approved_by => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    active => {
        data_type => 'tinyint',
        size      => '1',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => 0,
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
__PACKAGE__->utf8_columns(qw/ name email message url location comment comment_by /);

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Schema::Guest::Entry::Readonly->new({
            id          => $self->id,
            name        => $self->name,
            email       => $self->email,
            message     => $self->message,
            url         => $self->url,
            location    => $self->location,
            comment     => $self->comment,
            comment_by  => $self->comment_by,
            approved_by => $self->approved_by,
            active      => $self->active,
            ctime       => $self->ctime,
            mtime       => $self->mtime,
            approver    => undef,
        });
}

1;
