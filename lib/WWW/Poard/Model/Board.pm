package WWW::Poard::Resultset::Board;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

sub params {
    my ($self, $object) = @_;
    return {
    };
}

sub fetch_tree {
    my ($self, $id) = @_;
    my $params = {};
    if ($id) {
        my $root = $self->find($id) or return;
        $params = {
            lft => { '>=', $root->lft },
            rgt => { '<=', $root->rgt },
        };
    }
    my $search = $self->search($params,
        {
            order_by => 'lft',
        },
    );
    return $search;
}

sub sibling {
    my ($self, $object, $direction, $args) = @_;
    $args ||= {};
    my $search = $self->search({
        $direction eq 'left'
        ? (rgt => $object->lft - 1)
        : (lft => $object->rgt + 1)
    }, { %$args });
    return $search;
}

sub direct_parent {
    my ($self, $object, $args) = @_;
    $args ||= {};
    my $parents = $self->parents($object, $args);
    my $search = $parents->search({}, { order_by => 'lft desc', rows => 1});
    return $search;
}

sub parents {
    my ($self, $object, $args) = @_;
    $args ||= {};
    my ($lft, $rgt) = ($object->lft, $object->rgt);
    my $search = $self->search({
        lft => { '<', $lft },
        rgt => { '>', $rgt },
    }, { order_by => 'lft', %$args });
    return $search;
}

sub make_tree {
    my ($self, $type, $fields) = @_;
    $type ||= '</ul>';

    my $RGT;
    my @l;
    my $last_level = 1;
    my $nodes = [];
    while (my $node = $self->next) {
        my $last = 1;
        my ($id, $lft, $rgt) = ($node->id, $node->lft, $node->rgt);
        my $ro = $fields ? $node->readonly($fields) : $node->readonly;

        if (defined $RGT) {
            if ($rgt < $RGT) {
                # between, higher level
                $last = 0 if $rgt + 1 < $l[-1];
                push @l, $rgt;
            }
            elsif ($rgt > $RGT and $rgt > $l[-1]) {
                while (@l and $rgt > $l[-1]) {
                    pop @l;
                }
                $last = 0 if $rgt + 1 < $l[-1];
                push @l, $rgt;
            }
        }
        else {
            @l = $rgt;
        }
        $ro->set_level($#l);

        if (@$nodes and @l < $last_level) {
            $nodes->[-1]->set_level_down([(1) x ($last_level - @l)]);
        }
        if (@l > $last_level) {
            $ro->set_is_first(1);
        }
        $last_level = @l;
        $ro->set_is_last($last);
        push @$nodes, $ro;
        $RGT = $rgt;
    }
    if (@$nodes and 1 < $last_level) {
        $nodes->[-1]->set_level_down([(1) x ($last_level - 1)]);
    }
    return $nodes;

}

sub insert_new {
    my ($self, $id, $data) = @_;

    my ($lft, $rgt) = (1, 2);
    if ($id) {
        my $node = $self->find($id);
        my $upper = $self->search({
            lft => { '<=' => $node->lft },
            rgt => { '>=' => $node->rgt },
        });
        $upper->update({
            rgt => \'rgt + 2',
        });
        my $right = $self->search({
            lft => { '>' => $node->lft },
            rgt => { '>' => $node->rgt },
        });
        $right->update({
            lft => \'lft + 2',
            rgt => \'rgt + 2',
        });
        ($lft, $rgt) = ($node->rgt, $node->rgt + 1);
    }
    my $node = $self->create({
        %$data,
        lft => $lft,
        rgt => $rgt,
    });
    return $node;
}


package WWW::Poard::Model::Board;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ PK::Auto InflateColumn::Serializer Core /);
__PACKAGE__->table('poard_board');
__PACKAGE__->resultset_class('WWW::Poard::Resultset::Board');
__PACKAGE__->add_columns(
    id => {
        data_type => 'int',
        size      => '5',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    flags => {
        data_type => 'int',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
    },
    name => {
        data_type => 'varchar',
        size      => '64',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
    },
    description => {
        data_type => 'varchar',
        size      => '256',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '',
    },
    position => {
        data_type => 'int',
        size      => '5',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => '0',
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
    parent_id => {
        data_type => 'int',
        size      => '5',
        is_nullable => 1,
        is_auto_increment => 0,
        default_value => '0',
    },
    containmessages => {
        data_type => 'int',
        size      => '1',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => 0,
    },
    grouprequired => {
        data_type => 'int',
        size      => '10',
        is_nullable => 1,
        is_auto_increment => 0,
        default_value => 0,
    },
    meta => {
        data_type           => 'text',
        serializer_class    => 'JSON',
        is_nullable         => 1,
    },
#    mtime => {
#        data_type     => 'datetime',
#        set_on_create => 1,
#        set_on_update => 1,
#    },
#    ctime => {
#        data_type     => 'datetime',
#        set_on_create => 1,
#    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(sub_boards => __PACKAGE__, 'parent_id');
__PACKAGE__->has_many(threads => 'WWW::Poard::Model::Thread', 'board_id');

my @acc = qw/
    id name description position lft rgt parent_id containmessages grouprequired
    flags meta
/;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::Board::Readonly->new({
        is_expanded => 1,
    });
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $val = $self->$field;
        if ($field eq 'flags') {
            $val ||= 0;
        }
        $ro->$set($val);
    }
    return $ro;
}
sub is_leaf {
    $_[0]->lft + 1 == $_[0]->rgt
}


sub children_count {
    return ($_[0]->rgt - $_[0]->lft - 1) / 2
}

sub default_fields {
    qw/ id name description position parent_id containmessages grouprequired flags is_expanded /
}

1;
