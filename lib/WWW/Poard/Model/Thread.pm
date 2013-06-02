package WWW::Poard::Model::Thread;
use strict;
use warnings;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto InflateColumn::Serializer Core /);
__PACKAGE__->table('poard_thread');
__PACKAGE__->add_columns(
    id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    title => {
        data_type => 'varchar',
        size      => '128',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
    },
    meta => {
        data_type           => 'text',
        serializer_class    => 'JSON',
        is_nullable         => 1,
    },
    author_id => {
        data_type => 'int',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => undef,
    },
    author_name => {
        data_type => 'varchar',
        size      => '32',
        is_nullable => 1,
        is_auto_increment => 0,
        default_value => undef,
    },
    status => {
        data_type => "ENUM('active','deleted','onhold')",
        size      => '',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => 'onhold',
    },
    fixed => {
        data_type     => "tinyint",
        size          => '1',
        is_nullable   => 0,
        default_value => '0',
    },
    solved => {
        data_type     => "tinyint",
        size          => '1',
        is_nullable   => 0,
        default_value => '0',
    },
    is_tree => {
        data_type     => "tinyint",
        size          => '1',
        is_nullable   => 0,
        default_value => '0',
    },
    closed => {
        data_type => "tinyint(1)",
        size      => '',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
    },
    board_id => {
        data_type => 'int',
        size      => '5',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    read_count => {
        data_type => 'int',
        size      => '10',
        is_nullable => 1,
        is_auto_increment => 0,
        default_value => '0',
    },
    messagecount => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => 0,
    },
    approved_by => {
        data_type => 'int',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
    },
    is_survey => {
        data_type => 'tinyint',
        size      => '1',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
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
#__PACKAGE__->utf8_columns(qw/title author_name/);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(board => 'WWW::Poard::Model::Board','board_id');
__PACKAGE__->has_many('messages' => 'WWW::Poard::Model::Message', 'thread_id');
__PACKAGE__->has_many('surveys' => 'WWW::Poard::Model::Survey', 'thread_id');
__PACKAGE__->has_many('thread_tags' => 'WWW::Poard::Model::ThreadTag', 'thread_id');
__PACKAGE__->many_to_many('tags' => 'thread_tags', 'tag');


my @acc = qw/
    id title author_id author_name status fixed is_tree closed board_id read_count
    messagecount approved_by is_survey ctime mtime meta solved
/;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::Thread::Readonly->new({});
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        if ($field eq 'board') {
            $val = $val->readonly;
        }
        $ro->$set($val);
    }
    return $ro;
}

1;
