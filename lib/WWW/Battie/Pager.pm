package WWW::Battie::Pager;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use base 'Class::Accessor::Fast';
my @acc = qw(
    current link title total_count items_pp before after
    total_pages after_placeholder before_placeholder pages
    next previous last first spread
);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_wo_accessors(@acc);

sub init {
    my ($self) = @_;
    my $pp = $self->items_pp;
    my $total_count = $self->total_count;
    my $mod = $total_count % $pp;
    my $total_pages = int($total_count / $pp);
    $total_pages++ if $mod;
    $self->set_total_pages($total_pages);
    $self->current(1) unless $self->current;
    if ($self->current > $total_pages) {
        $self->set_current($total_pages);
    }
    $self->first;
    $self->last;
    $self->create_before_after;
    $self->create_next;
    $self->create_previous;
    return $self;
}

sub create_previous {
    my ($self) = @_;
    my $current = $self->current;
    my $total_pages = $self->total_pages;
    my $link = $self->link;
    my $title = $self->title;
    $current > 1 and $self->set_previous(WWW::Battie::Pager::Page->new({
                link => $link,
                title => $title,
                page => $current - 1,
            })->init());
}

sub create_next {
    my ($self) = @_;
    my $current = $self->current;
    my $total_pages = $self->total_pages;
    my $link = $self->link;
    my $title = $self->title;
    $current < $total_pages and $self->set_next(WWW::Battie::Pager::Page->new({
                link => $link,
                title => $title,
                page => $current + 1,
            })->init());
}

sub create_before_after {
    my ($self) = @_;
    my $current = $self->current;
    my $total_pages = $self->total_pages;
    my $link = $self->link;
    my $title = $self->title;
    my $after = $self->after;
    my $before = $self->before;
    if (!defined $after and !defined $before) {
        my $spread = $self->spread;
        $before = $after = $spread;
    }
    my @after_pages;
    my $ai = $current + 1;
    while ($ai < $total_pages) {
        last if $ai > $current + $after;
        my $page = WWW::Battie::Pager::Page->new({
                is_first => $ai == 1,
                is_last => $ai == $total_pages,
                link => $link,
                title => $title,
                page => $ai,
                active => 0,
            })->init;
        push @after_pages, $page;
        $ai++;
    }
    if (@after_pages and $after_pages[-1]->page < $total_pages - 1) {
        # we need a placeholder
        $self->set_after_placeholder(
            WWW::Battie::Pager::Placeholder->new({page=>0})
        );
    }

    my @before_pages;
    my $bi = $current - 1;
    while ($bi > 1) {
        last if $bi < $current - $before;
        my $page = WWW::Battie::Pager::Page->new({
                is_first => $bi == 1,
                is_last => $bi == $total_pages,
                link => $link,
                title => $title,
                page => $bi,
                active => 0,
            })->init;
        unshift @before_pages, $page;
        $bi--;
    }
    if (@before_pages and $before_pages[0]->page > 2) {
        # we need a placeholder
        $self->set_before_placeholder(
            WWW::Battie::Pager::Placeholder->new({page=>0})
        );
    }
    my $current_page = WWW::Battie::Pager::Page->new({
            page => $current,
            active => 1,
            link => $link,
            title => $title,
            is_first => $current == 1,
            is_last => $current == $total_pages,
        })->init;
    my @pages = (@before_pages, $current_page, @after_pages);
    $self->set_pages(
        $pages[0]->is_first ? () : $self->first,
        $self->before_placeholder || (),
        @pages,
        $self->after_placeholder || (),
        $pages[-1]->is_last ? () : $self->last,
    );
}

sub first {
    my ($self) = @_;
    my $current = $self->current;
    my $link = $self->link;
    my $title = $self->title;
    my $first = WWW::Battie::Pager::Page->new({
            page => 1,
            link => $link,
            title => $title,
            active => 0,
            is_first => 1,
            is_last => 0,
        })->init;
    if ($current == 1) {
        $first->set_active(1);
    }
    $self->set_first($first);
}

sub last {
    my ($self) = @_;
    my $current = $self->current;
    my $total_pages = $self->total_pages;
    my $link = $self->link;
    my $title = $self->title;
    my $last = WWW::Battie::Pager::Page->new({
            page => $total_pages,
            link => $link,
            title => $title,
            active => 0,
            is_first => 0,
            is_last => 1,
        })->init;
    if ($current == $total_pages) {
        $last->set_active(1);
    }
    $self->set_last($last);
}

package WWW::Battie::Pager::Placeholder;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw(page));
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_wo_accessors(qw(page));
package WWW::Battie::Pager::Page;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw(page link title active is_first is_last));
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_wo_accessors(qw(page link title active is_first is_last));

sub init {
    my ($self) = @_;
    my $page = $self->page;
    my $title = $self->title;
    my $link = $self->link;
    for ($title, $link)  {
        s/%p/$page/g;
    }
    $self->set_link($link);
    $self->set_title($title);
    return $self;
}

1;

__END__

=pod

=head1 NAME

WWW::Battie::Pager

=cut

