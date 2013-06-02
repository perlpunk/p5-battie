package WWW::Battie::Model::DBIC::Content::Page;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('content_page');
__PACKAGE__->add_columns(
    id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    title => {
        data_type => 'varchar',
        size      => '64',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    parent => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => 0,
    },
    position => {
        data_type => 'int',
        size      => '4',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => 0,
    },
    url => {
        data_type => 'varchar',
        size      => '32',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    text => {
        data_type => 'text',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    markup => {
        data_type     => "varchar",
        size          => 16,
        is_nullable   => 0,
        default_value => 'html',
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
#__PACKAGE__->utf8_columns(qw/title text/);

my @acc = qw/ id title text url parent position markup ctime mtime /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Battie::Model::DBIC::Content::Page::Readonly->new({
        });
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        $ro->$set($val);
    }
    return $ro;

#            id => $self->id,
#            title => $self->title,
#            text => $self->text,
#            url => $self->url,
#            parent => $self->parent,
#            position => $self->position,
#            markup => $self->markup,
#            ctime => $self->ctime,
#            mtime => $self->mtime,
#        });
}

package WWW::Battie::Model::DBIC::Content::Page::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw/ id title text url parent position markup ctime mtime ctime_epoch mtime_epoch rendered /;
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);
1;
