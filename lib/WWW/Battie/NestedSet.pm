package WWW::Battie::NestedSet;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);

sub create_nested_set {
    my ($class, $parent, $left, $right) = @_;
    my $var = $class . "::_nested_set";
    my $hash = {
        parent => $parent,
        left   => $left,
        right  => $right,
    };
    no strict 'refs';
    *{ $var } = $hash;
}

sub select_path {
    my ($class, $rs, $cat) = @_;
    my $var = $class . "::_nested_set";
    no strict 'refs';
    my @paths = $rs->search({
        left_id => { '<' => $cat->left_id },
        right_id => { '>' => $cat->right_id },
    });
    return \@paths;
}

sub select_children {
    my ($class, $rs, $id) = @_;
    my $var = $class . "::_nested_set";
    no strict 'refs';
    my @children;
    if ($id) {
        @children = $rs->search({
            parent_id => $id,
        });
    }
    else {
        my $cat = $rs->find({ left_id => 1 });
        @children = $cat ? $rs->search({
            parent_id => $cat->id,
        }) : ();
    }
    return (\@children);
}

sub insert_node {
    my ($class, $rs, $id, $data) = @_;
    my $var = $class . "::_nested_set";
    no strict 'refs';
    my ($left_id, $right_id, $parent_id) = (1, 2, 0);
    $data->{title} = 'root' unless defined $data->{title};
    if ($id) {
        my $cat = $rs->find($id) or return;
        my $upper = $rs->search({
            left_id => { '<=' => $cat->left_id },
            right_id => { '>=' => $cat->right_id },
        });
        $upper->update({
            right_id => \'right_id + 2',
        });
        my $right = $rs->search({
            left_id => { '>' => $cat->left_id },
            right_id => { '>' => $cat->right_id },
        });
        $right->update({
            left_id => \'left_id + 2',
            right_id => \'right_id + 2',
        });
        ($left_id, $right_id, $parent_id) = ($cat->right_id, $cat->right_id + 1, $cat->id);
    }
    my $node = $rs->create({
        %$data,
        left_id => $left_id,
        right_id => $right_id,
        parent_id => $parent_id,
    });
    return $node;
}

sub parent_node {
    my ($class, $rs, $id) = @_;
    my $cat = $rs->find($id) or return;
    my $upper = $rs->search({
        left_id => { '<' => $cat->left_id },
        right_id => { '>' => $cat->right_id },
    },
    {
        rows => 1,
        order_by => 'left_id desc',
    },
    )->single;
    return $upper;
}

sub delete_node {
    my ($class, $rs, $id) = @_;
    my $var = $class . "::_nested_set";
    no strict 'refs';
    my $cat = $rs->find($id) or return;
    my $upper = $rs->search({
        left_id => { '<=' => $cat->left_id },
        right_id => { '>=' => $cat->right_id },
    });
    $upper->update({
        right_id => \'right_id - 2',
    });
    my $right = $rs->search({
        left_id => { '>' => $cat->left_id },
        right_id => { '>' => $cat->right_id },
    });
    $right->update({
        left_id => \'left_id - 2',
        right_id => \'right_id - 2',
    });
    my $children = $rs->search({
        left_id => { '>' => $cat->left_id },
        right_id => { '<' => $cat->right_id },
    });
    $children->update({
        parent_id => $cat->parent_id,
    });
    $cat->delete;
    return 1;
}

sub fetch_tree {
    my ($class, $rs, $cat) = @_;
    if (!$cat) {
        $cat = $rs->find({ parent_id => 0 });
    }
    elsif (!ref $cat) {
        $cat = $rs->find($cat);
    }
    my @cats = $rs->search(
        {
            left_id => { '>=' => $cat->left_id },
            right_id => { '<=' => $cat->right_id },
        },
        {
            order_by => 'left_id ASC',
        },
    );
    my %levels;
    for my $cat (@cats) {
        $cat = $cat->readonly;
        my $p = $cat->parent_id;
        unless (%levels) {
            $levels{ $cat->id } = 0;
            $cat->set_level(0);
        }
        else {
            my $l = $levels{ $p };
            $levels{ $cat->id } = $l + 1;
            $cat->set_level($l + 1);
        }
    }
    return \@cats;
}

1;

