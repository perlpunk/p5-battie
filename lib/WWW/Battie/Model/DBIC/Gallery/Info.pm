package WWW::Battie::Model::DBIC::Gallery::Info;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('gallery_info');
__PACKAGE__->add_columns(
    id => {
        data_type         => 'int',
        size              => '10',
        is_nullable       => 0,
        is_auto_increment => 1,
    },
    cat_id => {
        data_type         => 'int',
        size              => '10',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    created_by => {
        data_type         => 'int',
        size              => '10',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    title => {
        data_type         => 'varchar',
        size              => '255',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    image_count => {
        data_type         => 'int',
        size              => '5',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => 0,
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
__PACKAGE__->utf8_columns(qw/title/);

__PACKAGE__->has_many('images' => 'WWW::Battie::Model::DBIC::Gallery::Image');
__PACKAGE__->belongs_to('cat' => 'WWW::Battie::Model::DBIC::Gallery::Category', 'cat_id');

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Model::DBIC::Gallery::Info::Readonly->new({
            id          => $self->id,
            created_by  => $self->created_by,
            title       => $self->title,
            image_count => $self->image_count,
            cat_id      => $self->cat_id,
            ctime       => $self->ctime,
            mtime       => $self->mtime,
            cat         => $self->cat ? $self->cat->readonly : undef,
        });
}

1;
