package WWW::Battie::Model::DBIC::Blog::Theme;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('theme');
__PACKAGE__->add_columns(
    id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    blog_id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    title => {
        data_type => 'varchar',
        size      => '256',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    abstract => {
        data_type => 'varchar',
        size      => '512',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    image => {
        data_type => 'varchar',
        size      => '256',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    link => {
        data_type => 'varchar',
        size      => '256',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    message => {
        data_type => 'text',
        is_nullable => 1,
        size      => undef,
    },
    posted_by => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    active => {
        data_type     => 'int',
        size          => '1',
        is_nullable   => 0,
        default_value => 0,
    },
    is_news => {
        data_type     => 'int',
        size          => '1',
        is_nullable   => 0,
        default_value => 0,
    },
    can_comment => {
        data_type     => 'int',
        size          => '1',
        is_nullable   => 0,
        default_value => 0,
    },
    mtime => {
        data_type     => 'datetime',
        set_on_update => 1,
        set_on_create => 1,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->utf8_columns(qw/title abstract message/);

__PACKAGE__->belongs_to(blog => 'WWW::Battie::Model::DBIC::Blog::Blog','blog_id');

sub readonly {
    my ($self, $select) = @_;
    my $fields = {
        id          => $self->id,
        blog_id     => $self->blog_id,
        title       => $self->title,
        abstract    => $self->abstract,
        image       => $self->image,
        link        => $self->link,
        message     => $self->message,
        posted_by   => $self->posted_by,
        active      => $self->active,
        is_news     => $self->is_news,
        can_comment => $self->can_comment,
        ctime       => $self->ctime,
        mtime       => $self->mtime,
        blog        => $self->blog->readonly,
    };
    my $selected = {};
    if ($select) {
        @$selected{ @$select } = @$fields{ @$select };
    }
    else {
        $selected = $fields;
    }
    my $ro = WWW::Battie::Model::DBIC::Blog::Theme::Readonly->new($selected);
}

1;
