package WWW::Battie::Model::DBIC::Content::News;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto UTF8Columns Core /);
__PACKAGE__->table('news');
__PACKAGE__->add_columns(
    id => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    headline => {
        data_type => 'varchar',
        size      => '256',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    message => {
        data_type => 'text',
        size      => undef,
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

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Model::DBIC::Content::News::Readonly->new({
            id => $self->id,
            headline => $self->headline,
            message => $self->message,
            ctime => $self->ctime,
            mtime => $self->mtime,
        });
}

package WWW::Battie::Model::DBIC::Content::News::Readonly;
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_ro_accessors(qw(id headline message ctime mtime));

1;
