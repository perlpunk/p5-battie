package WWW::Battie::Model::DBIC::Blog::Blog;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('blog');
__PACKAGE__->add_columns(
    id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    title => {
        data_type => 'varchar',
        size      => '256',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    image => {
        data_type => 'varchar',
        size      => '256',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    created_by => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 0,
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
__PACKAGE__->utf8_columns(qw/title/);

__PACKAGE__->has_many('themes' => 'WWW::Battie::Model::DBIC::Blog::Theme', 'blog_id');

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Model::DBIC::Blog::Blog::Readonly->new({
            id => $self->id,
            title => $self->title,
            image => $self->image,
            created_by => $self->created_by,
            ctime => $self->ctime,
            mtime => $self->mtime,
        });
}

1;
