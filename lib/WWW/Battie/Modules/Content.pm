package WWW::Battie::Modules::Content;
use strict;
use warnings;
use Carp qw(carp croak);
use base qw/ WWW::Battie::Module::Model WWW::Battie::Module::Search Class::Accessor::Fast /;
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(url));
my %functions = (
    functions => {
        content => {
            start => 1,
            view => 1,
            init => {
                on_run => 1,
            },
            show_content_navigation => {
                on_run => 1,
            },
            search_nodelet => 1,
            search => 1,
            show_motd_nodelet => 1,
        },
    },
);
sub functions { %functions }

sub default_actions {
    my ($class, $battie) = @_;
    return {
        guest => [qw/ start view init show_content_navigation /],
        content_editor => [],
    };
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        my $pages = $battie->get_data->{content}->{pages};
        my $page = $pages->[0]->{page};
        my $url = $page ? $page->url : undef;
        my $title = $page ? $page->title : '';
        return {
            link => ['content', 'view', $url],
            text => $title,
        };
    };
}

sub content__show_motd_nodelet {
    my ($self, $battie) = @_;
    my $motd = $self->fetch_current_motd($battie);
    return $motd->rendered;
}


sub model {
    content => 'WWW::Battie::Model::DBIC::Content'
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    my $url = $args->{URL};
    my $self = $class->new({
            url => $url,
        });
}

sub search_options {
    my ($self, $battie, $page, $action) = @_;
    return [];
    my %options = (
#        '*' => [{content => 'Content'}],
#        content => {
#            view => [{content => "-- This Page"}],
#        },
    );
    return \%options;
}


sub content__init {
    my ($self, $battie) = @_;
    my $url = $self->get_url;
    my $docurl = $battie->get_paths->{docurl};
    $battie->get_data->{content}->{url} = $docurl . $url;
#    if ($battie->allow->can_do(content => 'show_motd_nodelet')) {
#        return unless $battie->response->get_needs_navi;
#        my $motd = $self->fetch_current_motd($battie);
#        $battie->get_data->{content}->{show_motd} = $motd;
#    }
}

sub fetch_current_motd {
    my ($self, $battie) = @_;
    my $cached = $battie->from_cache('content/motd');
    my $motd;
    if ($cached) {
        $motd = $cached->{motd};
    }
    else {
        $battie->timer_step("motd");
        $self->init_db($battie);
        my $schema = $self->get_schema->{content};
        my $now = DateTime->now;
        my $search = $schema->resultset('MOTD')->search({
                start => { '<=', $now },
                end => { '>=', $now },
            }, {
                select => [qw/ id weight content /],
            });
        my @list;
        my $sum = 0;
        while (my $motd = $search->next) {
            my $weight = $motd->weight;
            my $to = $sum + $weight;
            push @list, [$sum, $to, $motd];
            $sum += $weight;
        }
        if (@list) {
            my $rand = int rand $sum;
            for my $item (@list) {
                my ($from, $to, $m) = @$item;
                if ($from <= $rand and $to > $rand) {
                    $motd = $m;
                    last;
                }
            }
            $motd = $motd->readonly([qw/ content /]);
            my $re = $battie->get_render->render_message_html($motd->content);
            $motd->set_rendered($re);
            $motd->set_content(undef);
        }
        $cached->{motd} = $motd;
        $battie->to_cache('content/motd', $cached, 60);
        $battie->timer_step("motd end");
    }
    return $motd;
}

sub content__search {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $where = $request->param('query.where') || 'content';
    my ($mod) = split m#/#, $where, 2;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$mod], ['mod']);
    if ($mod ne 'content') {
        #warn __PACKAGE__.':'.__LINE__.": ;;;;;;;;;;;;;;;;;;;;;;;;;;;;; $mod\n";
        $battie->internal_redirect($mod => 'search');
        return;
    }
    my $from = $request->param('from') || '';
    my $query = $request->param('query');

}

sub content__search_nodelet {
    my ($self, $battie) = @_;
}

sub content__show_content_navigation {
    my ($self, $battie) = @_;
    return unless $battie->response->get_needs_navi;
    my $pages = $battie->from_cache('content/navigation');
    my $data = $battie->get_data;
    $self->init_db($battie);
    unless ($pages) {
        my $request = $battie->get_request;
            my ($page, $action) = ($request->get_page, $request->get_action);
#            if ($page eq 'content' and $action eq 'view') {
#                    return;
#            }
            #return;
        my $schema = $self->get_schema->{content};
        my $parent = 0;
        my ($path, @pages) = $self->create_content_navi($parent);
        $pages = \@pages;
        $battie->to_cache('content/navigation', $pages, 60 * 15);
    }
    $data->{content}->{pages} = $pages;
}

sub content__start {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    my $data = $battie->get_data;
    $self->init_db($battie);
    my $schema = $self->get_schema->{content};
    my $home = $schema->resultset('Page')->search({
        url => "home",
    })->single;
    if ($home) {
        my $id = $home->url;
        $battie->set_local_redirect("/content/view/$id");
    }
    #$data->{pages} = \@pages;
}

sub content__view {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    my $schema = $self->get_schema->{content};
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($url) = @$args;
    $self->exception("Argument", "Not a valid page id") unless $schema->valid_link($url);
    my $ck = "content/pagenavi/$url";
    my $cached = $battie->from_cache($ck);
    my $page_ro = $cached->{page};
    my $path = $cached->{path};
    my $pages = $cached->{pages};
    unless ($page_ro) {
        my $page_rs = $schema->resultset('Page');
        my $page = $page_rs->find({url => $url});
        $self->exception("Argument", "Page does not exist") unless $page;
        $page_ro = $page->readonly;
        $self->_times_for_cache($page_ro);
        my $rendered = $self->render_textile($battie, $page_ro->text);
        $page_ro->set_rendered($rendered);
        my @pages;
        ($path, @pages) = $self->create_content_navi($page_ro);
        $cached = {
            page => $page_ro,
            path => $path,
            pages => \@pages,
        };
        $pages = \@pages;
        $battie->to_cache($ck, $cached, 60 * 60 * 24);
    }
    my $data = $battie->get_data;
    $battie->crumbs->pop;
    for my $page (reverse @$path) {
        $battie->crumbs->append($page->title, "content/view/" . $page->url);
    }
    $data->{content}->{sub_pages} = $pages;
    $data->{content}->{page} = $page_ro;
    $data->{content}->{html} = $page_ro->rendered;
    $data->{subtitle} = $page_ro->title;
}

sub _times_for_cache {
    my ($self, $item) = @_;
    if ($item->ctime) {
        $item->set_ctime_epoch($item->ctime->epoch);
        $item->set_ctime(undef);
    }
    if ($item->mtime) {
        $item->set_mtime_epoch($item->mtime->epoch);
        $item->set_mtime(undef);
    }
}


sub render_textile {
    my ($self, $battie, $text) = @_;
    my $textile = $battie->new_textile;
    $textile->disable_html(1);
    my $html = $textile->process($text);
    return $html;
}

sub create_content_navi {
    my ($self, $parent_page) = @_;
    my $parent = ref $parent_page ? $parent_page->id : $parent_page;
    my $schema = $self->get_schema->{content};
    my $page_rs = $schema->resultset('Page');
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$parent], ['parent']);
    #return;
    my $all_sub_pages = $page_rs->search(
        {
            position => { '>' => 0 },
            parent => $parent,
        },
        {
            order_by => 'position',
            select => [qw/ id url title parent /],
        },
    );
		my @sub_pages;
		while (my $p = $all_sub_pages->next) {
				push @sub_pages, $p->readonly;
		}
		my @path;
    if (ref $parent_page) {
        my $current_id = $parent_page->parent;;
        my $c = 0;
        while (1 and $current_id) {
            my $p = $page_rs->find($current_id, {
                    select => [qw/ id url title parent /],
                });
            $current_id = $p->parent;
            push @path, $p->readonly;
            last if $c++ == 3;
        }
        unshift @path, $parent_page;
    }
    my @pages;
    my $all_pages = $page_rs->search(
        {
            position => { '>' => 0 },
            parent => 0,
        },
        {
            order_by => 'position',
            select => [qw/ id url title parent /],
        },
     );
     my $root = @path>0 ? $path[-1]->get_id : 0;
     #warn __PACKAGE__.$".Data::Dumper->Dump([\@path], ['path']);
     while (my $p = $all_pages->next) {
				my $entry = {
						page => $p->readonly([qw/ url title /]),
				};
        #warn __PACKAGE__.$".Data::Dumper->Dump([\$entry], ['entry']);
				my $pid = $p->id;
        #warn __PACKAGE__." $pid == $root?\n";
				if ($p->id == $root) {
						$entry->{subs} = \@sub_pages if @sub_pages;
						$entry->{path} = [reverse @path];
				}
        push @pages, $entry;
    }
    return (\@path, @pages);
}

1;
