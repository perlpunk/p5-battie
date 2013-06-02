package WWW::Poard::Resultset::Message;
use strict;
use warnings;
use base qw/ DBIx::Class::ResultSet /;

sub insert_new {
    my ($self, $id, $data) = @_;

    my ($lft, $rgt) = (1, 2);
    if ($id) {
        my $node = $self->find($id);
        ($lft, $rgt) = ($node->rgt, $node->rgt + 1);
        my $upper = $self->search({
            lft => { '<=' => $node->lft },
            rgt => { '>=' => $node->rgt },
            thread_id => $node->thread_id,
        });
        $upper->update({
            rgt => \'rgt + 2',
        });
        my $right = $self->search({
            lft => { '>' => $node->lft },
            rgt => { '>' => $node->rgt },
            thread_id => $node->thread_id,
        });
        $right->update({
            lft => \'lft + 2',
            rgt => \'rgt + 2',
        });
    }
    my $node = $self->create({
        %$data,
        lft => $lft,
        rgt => $rgt,
    });
    return $node;
}

sub parents {
    my ($self, $object, $args) = @_;
    $args ||= {};
    my ($lft, $rgt) = ($object->lft, $object->rgt);
    my $search = $self->search({
        lft => { '<', $lft },
        rgt => { '>', $rgt },
        thread_id => $object->thread_id,
    }, { order_by => 'lft', %$args });
    return $search;
}


package WWW::Poard::Model::Message;
use base qw/ DBIx::Class WWW::Battie::NestedSet /;
use base qw/ WWW::Battie::Nested::Schema /;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('poard_message');
 __PACKAGE__->resultset_class('WWW::Poard::Resultset::Message');
__PACKAGE__->add_columns(
    id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    title => {
        data_type	=> 'varchar',
        size		=> '128',
        is_nullable => 1,
    },
    thread_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
    },
    author_id => {
        data_type => 'int',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
    },
    position => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
    },
    changelog => {
        data_type       => 'int',
        size            => '1',
        is_nullable     => 0,
        default_value   => '0',
    },
    has_attachment => {
        data_type       => 'int',
        size            => '1',
        is_nullable     => 0,
        default_value   => '0',
    },
    lft => {
        data_type => 'int',
        size      => '10',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    rgt => {
        data_type => 'int',
        size      => '10',
        is_nullable => 1,
        is_auto_increment => 0,
    },
    lasteditor => {
        data_type => 'int',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
    },
    approved_by => {
        data_type => 'int',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
    },
    message => {
        data_type => 'text',
        size      => '',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
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
#__PACKAGE__->utf8_columns(qw/ message author_name title /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(thread => 'WWW::Poard::Model::Thread','thread_id');

my @acc = qw/
    id thread_id title author_id author_name position lft rgt lasteditor approved_by
    message status ctime mtime changelog has_attachment
/;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::Message::Readonly->new({
        is_editable => 0,
    });
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        if ($field eq 'mtime') {
            # mtime shouldn't be set if message wasn't edited
            $val = (!$self->ctime or $self->ctime ne $self->mtime) ? $self->mtime : undef;
        }
        $ro->$set($val);
    }
    return $ro;
}

1;
