package WWW::Battie::Model::DBIC::Gallery::Image;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('gallery_image');
__PACKAGE__->add_columns(
    id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    info => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    position => {
        data_type => 'int',
        size      => '4',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    title => {
        data_type => 'varchar',
        size      => '255',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    suffix => {
        data_type => 'varchar',
        size      => '4',
        is_nullable => 0,
        is_auto_increment => 0,
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

__PACKAGE__->belongs_to(info => 'WWW::Battie::Model::DBIC::Gallery::Info','info');

sub readonly {
    my ($self, $select) = @_;
    my $fields = {
        id => $self->id,
        info => $self->info->readonly,
        title => $self->title,
        suffix => $self->suffix,
        position => $self->position,
        ctime => $self->ctime,
        mtime => $self->mtime,
    };
    my $selected = {};
    if ($select) {
        @$selected{ @$select } = @$fields{ @$select };
    }
    else {
        $selected = $fields;
    }
    my $ro = WWW::Battie::Model::DBIC::Gallery::Image::Readonly->new($selected);
    return $ro;
}


1;
