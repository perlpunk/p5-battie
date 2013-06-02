package WWW::Battie::Model::DBIC::Gallery::Category;
use base qw/ DBIx::Class WWW::Battie::NestedSet /;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('gallery_category');
__PACKAGE__->add_columns(
    id => {
        data_type         => 'int',
        size              => '10',
        is_nullable       => 0,
        is_auto_increment => 1,
    },
    parent_id => {
        data_type         => 'int',
        size              => '10',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    left_id => {
        data_type         => 'int',
        size              => '10',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    right_id => {
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
    mtime => {
        data_type     => 'datetime',
        set_on_create => 1,
        set_on_update => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->utf8_columns(qw/title/);

#__PACKAGE__->has_many('images' => 'WWW::Battie::Model::DBIC::Gallery::Image');

__PACKAGE__->create_nested_set(qw/ parent_id left_id right_id /);

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Model::DBIC::Gallery::Category::Readonly->new({
            id          => $self->id,
            title       => $self->title,
            parent_id   => $self->parent_id,
            left_id     => $self->left_id,
            right_id    => $self->right_id,
            mtime       => $self->mtime,
        });
    return $ro;
}

1;
