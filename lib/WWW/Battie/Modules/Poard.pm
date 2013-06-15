package WWW::Battie::Modules::Poard;
use strict;
use warnings;
use Carp qw(carp croak);
use base qw/ WWW::Battie::Module::Model WWW::Battie::Module::Search Class::Accessor::Fast /;
use MIME::Base64 qw/ encode_base64url /; 
use JSON qw/ to_json /;
use Image::Resize;
use File::LibMagic;
use Date::Parse;
use List::Util;
use DateTime;
use URI::Escape qw/ uri_escape uri_escape_utf8 /;
use Time::HiRes qw/ gettimeofday tv_interval /;
use File::Temp qw/ tempfile /;
use File::Copy qw/ move /;
use File::Path qw/ mkpath /;
use Encode;
use Fcntl qw/ :flock :seek /;
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(
    max_unapproved max_unapproved_threads post_delay max_length_rss_msg
    rss_title html_titles statistics search rows lcache antispam attachment
    post_hint
));

my $string_diff;
BEGIN {
    $string_diff = eval "use String::Diff qw/ diff /; 1;";
}
{
my %functions = (
    functions => {
        poard => {
            start                   => 1,
            statistic               => 1,
            board                   => 1,
            thread                  => 1,
#            thread_mini             => 1,
            message                 => 1,
            latest                  => 1,
            post_answer             => 1,
            post_answer_authorized  => 0,
            survey_vote             => 1,
            create_thread           => 1,
            create_survey           => 1,
            close_survey            => 1,
            edit_survey             => 1,
            edit_survey_change      => 0,
            edit_message            => 1,
            message_attach          => 0,
            attachment              => 1,
            solve_thread            => 1,
            edit_thread_title       => 1,
            edit_thread_tags        => 1,
            mod_edit_thread         => 0,
            subscribe_thread        => 1,
            toggle_board_view       => 1,
            msgs_by_nick            => 1,
            view_board              => 1,
            view_thread             => 1,
            view_message            => 1,
            view_latest             => 1,
            view_subscriptions      => 1,
            subscriptions           => 1,
            search                  => 1,
            settings                => 1,
            markup_help             => 1,
            tag_suggest             => 1,

            approve_message         => 1,
            show_unapproved_messages => 1,

#            mod_move_node           => 1,
            mod_close_survey        => 0,
            mod_view_message_log    => 1,
            view_message_log        => 1,
            mod_view_thread_log     => 1,
            mod_view_message_diff   => 1,
            mod_edit_message        => 0,
            mod_solve_thread        => 0,
            mod_delete_thread       => 1,
            mod_delete_message      => 1,
            mod_undelete_message    => 1,
            mod_undelete_thread     => 1,
            mod_move_thread         => 1,
            mod_fix_thread          => 1,
            mod_close_thread        => 1,
            mod_split_thread        => 1,
            mod_reparent            => 1,
            mod_merge_thread        => 1,
            mod_view_deleted_thread => 0,
            view_trash              => 1,

            admin_edit_board        => 1,
            admin_list_boards       => 1,
            admin_really_delete     => 1,

            xml_messages_rss => {
                # won't create a session, or update the current session
                # will set a dummy session
                no_session => 1,
            },

            init =>{
                on_run => 1,
            },
        },
    },
);
sub functions { %functions }
}

sub default_actions {
    my ($class, $battie) = @_;
    return {
        guest => [qw/ start statistic board thread message latest view_board view_thread view_message view_latest post_answer create_thread toggle_board_view xml_messages_rss init markup_help tag_suggest attachment /],
        user => [qw/ post_answer_authorized survey_vote create_survey close_survey edit_survey edit_message
        subscribe_thread msgs_by_nick subscriptions view_subscriptions settings
        edit_thread_title edit_thread_tags solve_thread view_message_log message_attach /],
        janitor => [qw/ approve_message show_unapproved_messages /],
        moderator => [qw/ mod_view_message_log mod_view_message_diff mod_edit_message mod_edit_thread mod_delete_thread
        mod_delete_message mod_undelete_message mod_undelete_thread mod_move_thread
        mod_fix_thread mod_close_thread mod_split_thread mod_reparent mod_merge_thread
        mod_view_deleted_thread view_trash mod_solve_thread mod_view_thread_log
        mod_close_survey edit_survey_change /], #mod_move_node 
        board_admin => [qw/ admin_edit_board admin_list_boards admin_really_delete /],
    };
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        return {
            link => ['poard', 'start'],
#            image => "settings.png",
            text => 'Forum',
        };
    };
}
#<a href="[%= .self %]/poard/start">Forum</a>



my $rows_in_thread = 10;

sub search_options {
    my ($self, $battie, $page, $action) = @_;
    my @opt = (
        [0, 'poard' => 'Board' ],
    );
    if ($action =~ m/(view_)?(board|thread)/) {
        push @opt, [1, 'poard/board' => '-- This Board'];
    }
    if ($action =~ m/(view_)?(thread)/) {
        push @opt, [0, 'poard/thread' => '--- This Thread'];
    }
    return \@opt;
}

sub model {
    poard => 'WWW::Poard::Model',
    user => 'WWW::Battie::Schema::User',
}

sub title {
    return 'Board'
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$args], ['args']);
    my $max_unapproved = $args->{MAX_UNAPPROVED};
    my $rows_board = $args->{ROWS_BOARD} || 20;
    my $max_unapproved_threads = $args->{MAX_UNAPPROVED_THREADS};
    my $post_delay = $args->{POST_DELAY} || 1;
    my $post_hint = $args->{POST_HINT} ? 1 : 0;
    my $stat_groups = $args->{STATISTICS_GROUPING} || '0,1,2,3,5,10,20';
    my $stat_rows = $args->{STATISTICS_ROWS_PP} || 50;
    $stat_groups = [split m/\s*,\s*/, $stat_groups];
    my %titles = (
        board   => $args->{HTML_TITLE_BOARD}  || 'Board %board',
        thread  => $args->{HTML_TITLE_THREAD} || 'Board %board - Thread %thread',
        message => $args->{HTML_TITLE_MSG}    || 'Board %board - Thread %thread - #%id',
    );
    my $attchment_types = $args->{ATTACHMENT_TYPES} || '';
    my $attach_dir = $args->{ATTACHMENT_PATH};
    $attach_dir = File::Spec->catfile($battie->get_paths->{serverroot}, $attach_dir);
    my $thumb_dir = $args->{ATTACHMENT_THUMBNAILS};
    my %attachment_types = map { $_ => 1 } split ';', $attchment_types;
    my $self = $class->new({
            max_unapproved => $max_unapproved,
            max_unapproved_threads => $max_unapproved_threads,
            post_delay     => $post_delay,
            max_length_rss_msg => $args->{MAX_LENGTH_RSS_MSG} || 100,
            rss_title      => $args->{RSS_TITLE},
            html_titles    => \%titles,
            post_hint => $post_hint,
            statistics     => {
                groups => $stat_groups,
                rows   => $stat_rows,
            },
            rows   => {
                board => $rows_board,
            },
            search  => {},
            lcache  => {},
            ($args->{ANTISPAM} ? (antispam => $args->{ANTISPAM}) : ()),
            attachment => {
                path            => $attach_dir,
                types           => \%attachment_types,
                tmpdir          => $args->{ATTACHMENT_TMPDIR} || '/tmp',
                thumbdir        => $thumb_dir,
                max             => $args->{ATTACHMENT_MAX} || 5,
                max_size        => $args->{ATTACHMENT_MAX_SIZE} || 1024,
                max_totalsize   => $args->{ATTACHMENT_MAX_TOTALSIZE} || 1024,
            },
        });
    my $searchclass = $args->{SEARCH} || 'Database';
    my $search_index = $args->{SEARCH_INDEX};
    my $search_conf = $self->get_search;
    $search_conf->{class} = $searchclass;
    if ($searchclass eq 'KinoSearch') {
        eval {
            # if there is no index yet
            $search_conf->{index} = $search_index;
            $search_conf->{last_init} = 0;
            $self->reinitialize_indexer;
        };
    }
    return $self;
}
my %defaults = (
    articles => {
        signature   => 1,
        avatar      => 1,
        hide_old_branches => 0,
    },
    edit => {
        textarea    => {
            cols   => 75,
            rows  => 10,
        },
    },
    overview => {
    },
);
sub settings_defaults {
    \%defaults
}

sub poard__init {
    my ($self, $battie) = @_;
    my $data = $battie->get_data;
    # set additional css link
    if ($battie->request->get_page eq 'poard') {
        $data->{userprefs}->{local_css}->{'source-highlight'} = 'source-highlight';
        $data->{userprefs}->{local_css}->{'poard'} = 'poard';
        $data->{userprefs}->{local_color_css}->{'poard'} = 'poard';
        $data->{userprefs}->{local_js}->{'bbcode_buttons'} = 1;
        $data->{userprefs}->{local_js}->{'poard'} = 1;
    }
    $data->{userprefs}->{local_rss}->{$battie->self_url . '/poard/xml_messages_rss'} = $self->get_rss_title . " (abstracts)";
    $data->{userprefs}->{local_rss}->{$battie->self_url . '/poard/xml_messages_rss?type=full'} = $self->get_rss_title . " (full)";
}

sub poard__tag_suggest {
    my ($self, $battie) = @_;
    my $render = $battie->get_render;
    my $data = $battie->get_data;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $request = $battie->request;
    my $ajax = $request->param('is_ajax');
    if ($ajax) {
        $data->{main_template} = "poard/ajax.html";
    }
    my $tag = $request->param('tag');
    my $tags = {};
    if (defined $tag) {
        $tag =~ s/^\s+//;
        $tag =~ s/\s+\z//;
        my $ck;
        if (length $tag < 4) {
            # only cache suggestions for input < 4 chars
            $ck = "poard/tag_suggest/tag_" . encode_base64url($tag);
        }
#        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$ck], ['ck']);
#        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$tag], ['tag']);
        if ($ck) {
            $tags = $battie->from_cache($ck);
        }
        unless ($tags) {
            $tags = {
                name    => $tag,
                list    => [],
                more    => 0,
            };
            $tag =~ s#\\#\\\\#g;
            $tag =~ s#%#\\%#g;
            my $search = $schema->resultset('Tag')->search({
                    name => { LIKE => "$tag%" },
                },
                {
                    rows => 21,
                    order_by => 'name asc',
                    join => 'thread_tags',
                    group_by => 'me.id',
                    select => [
                        qw/ me.id name /,
                        { count => 'thread_tags.thread_id' },
                    ],
                    as => [qw/ id name thread_count /],
                });
            while (my $tag = $search->next) {
                my $threads = $tag->get_column('thread_count');
                push @{ $tags->{list} }, {
                    name    => $tag->name,
                    count   => $threads,
                };
            }
            if (@{ $tags->{list} } > 20) {
                pop @{ $tags->{list} };
                $tags->{more} = 1;
            }
            if ($ck) {
                $battie->to_cache($ck, $tags, 60 * 60);
            }
        }
    }
    $data->{poard}->{tag_suggestions} = $tags;
    my $count = 0;
    if ($tags->{list}) {
        $count = @{ $tags->{list} };
        $count = 10 if $count > 10;
    }
    $data->{poard}->{tag_suggestions_size} = $count;
}

sub poard__markup_help {
    my ($self, $battie) = @_;
    my $render = $battie->get_render;
    my $tags = $render->get_htmltags;
    my $data = $battie->get_data;
    my @tags;
    my $request = $battie->request;
    my $ajax = $request->param('is_ajax');
    if ($ajax) {
        $data->{main_template} = "poard/ajax.html";
    }
    for my $name (sort keys %$tags) {
        my $value = $tags->{$name};
        next unless ref $value eq 'HASH';
        my $example = $value->{example} or next;
        my $result = $example->{result};
        my $source = $example->{source};
        unless ($result) {
            $result = $battie->get_render->render_message_html($source);
            $example->{result} = $result;
        }
        if ($ajax) {
            $source =~ s/</&lt;/g;
            $source =~ s/\n/<br>/g;
        }
        push @tags, {
            name => $name,
            source => $source,
            result => $result,
            description => $example->{description},
        };
    }
    $data->{poard}->{markup}->{tags} = \@tags;
}

sub poard__search {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $query = $request->param('query');
    my $args = $request->get_args;
    my ($search_type, @more_args) = @$args;
    $search_type ||= 'text';
    $query = '' unless defined $query;
    my @tags = $request->param('tag');
    my $where = $request->param('query.where') || 'poard';
    my $from = $request->param('from');
    my $in_board = 0;
    my $in_thread = 0;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$from], ['from']);
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$where], ['where']);
    my ($search_board, $search_thread);
    my $tid;
    my $bid;
    my $thread;
    my $board;
    if ($from) {
        if ($where eq 'poard/board' and $from =~ m{poard/(?:view_)?board/(\d+)}) {
            $in_board = $1;
            $bid = $1;
        }
        elsif ($where eq 'poard/board' and $from =~ m{poard/(?:view_)?thread/(\d+)}) {
            my $tid = $1;
            my $thread = $schema->resultset('Thread')->find($tid);
            $in_board = $thread->board_id;
            $bid = $in_board;
        }
        elsif ($where eq 'poard/thread' and $from =~ m{poard/(?:view_)?thread/(\d+)}) {
            $in_thread = $1;
            $tid = $1;
        }
    }
    elsif ($tid = $request->param('stid')) {
        $in_thread = $tid;
    }
    elsif ($bid = $request->param('sbid')) {
        $in_board = $bid;
    }
    if ($bid) {
        $board = $schema->resultset('Board')->find($bid);
    }
    elsif ($tid) {
        $thread = $schema->resultset('Thread')->find($tid);
    }
    my @boards;
    if ($in_board) {
        my $board = $schema->resultset('Board')->find($in_board);
        if ($board->lft == 1) {
            @boards = $schema->resultset('Board')->search({
                lft => { '>=' => $board->lft },
                rgt => { '<=' => $board->rgt },
            })->all;
        }
        else {
            @boards = $board;
        }
    }
    elsif ($in_thread) {
        my $thread = $schema->resultset('Thread')->find($in_thread);
        @boards = $thread->board;
    }
    else {
        @boards = $schema->resultset('Board')->search({})->all;
    }
    my @allowed = $self->check_board_group($battie, @boards);
    my %all = map { ( $_->id => 1 ) } @boards;
    my $board_ids = [map $_->id, @allowed];
    for my $allowed (@$board_ids) {
        delete $all{$allowed};
    }
    my $rows = $request->param('rows') || 20;
    { no warnings; $rows = int $rows;
    }
    if ($rows > 100) {
        $rows = 100;
    }
    my $search_term = $query;
    my $data = $battie->get_data;
    my @rows = (10, 20, 30, 40, 50);
    $data->{poard}->{search}->{numrows} = $rows;
    $data->{poard}->{search}->{rows} = [
        $rows, ((grep { $rows == $_ } @rows) ? () : $rows), @rows,
    ];
    $self->reinitialize_indexer;
    my $search_conf = $self->get_search;
    if ($search_conf->{class} eq 'KinoSearch') {
        $data->{poard}->{kinosearch} = 1;
    }
    my $by_date = $request->param('by_date');
    $data->{poard}->{search}->{sort_by_date} = $by_date;
    my $in_title = $request->param('in_title');
    $data->{poard}->{search}->{search_in_title} = $in_title;
    if (length $query > 1) {
        my $page = $request->pagenum(1000); # not more than 1000 pages;
        my @found;
        my $count;
        if ($search_conf->{class} eq 'KinoSearch') {
            my $searcher = $search_conf->{searcher};

            my $sort_spec = KinoSearch::Search::SortSpec->new(
                rules => [
                    KinoSearch::Search::SortRule->new( field => 'date', reverse => 1 ),
                    KinoSearch::Search::SortRule->new( type  => 'score' ),
                ],
            );

            my @bools;
            for my $not_allowed (keys %all) {
                my $board_only     = KinoSearch::Search::TermQuery->new(
                    field   => 'board_id',
                    term => $not_allowed,
                );
                my $not = KinoSearch::Search::NOTQuery->new(
                    negated_query => $board_only,
                );
                push @bools, $not,
            }
            my $query_parser = $in_title
                ? $search_conf->{query_parser_title}
                : $search_conf->{query_parser};
            my $general_query = $query_parser->parse($query);
            push @bools, $general_query;
            if ($in_thread) {
                warn __PACKAGE__.':'.__LINE__.": ONLY $in_thread\n";
                my $thread_only = KinoSearch::Search::TermQuery->new(
                    field   => 'thread_id',
                    term => $in_thread,
                );
                push @bools, $thread_only;
            }
            elsif ($in_board) {
                my $board_only = KinoSearch::Search::TermQuery->new(
                    field   => 'board_id',
                    term => $in_board,
                );
                push @bools, $board_only;
            }
            my $bool_query = KinoSearch::Search::ANDQuery->new(
                children => [@bools],
            );
            my $best;
            {
                my $hits = $searcher->hits(
                    #query => $bool_query,
                    query => $query,
                    num_wanted => 1,
                );
                my $first = $hits->next;
                $best = $first ? $first->get_score : 1;
            }
            #warn __PACKAGE__.':'.__LINE__.": BEST SCORE: $best\n";
            my $hits = $searcher->hits(
                query => $bool_query,
                #query => $query,
                $by_date ? (sort_spec => $sort_spec) : (),
                offset => ($page - 1) * $rows,
                num_wanted => $rows,
            );
            $count = $hits->total_hits;
            require KinoSearch::Highlight::Highlighter;
            my $highlighter = KinoSearch::Highlight::Highlighter->new(
                searchable  => $searcher,
                query       => $query,
                field       => 'body',
            );
            my $highlighter2 = KinoSearch::Highlight::Highlighter->new(
                searchable  => $searcher,
                query       => $query,
                field       => 'title',
            );
            my %uids;
            my $boards = $self->fetch_boards($battie);
            while ( my $hit = $hits->next ) {
                my $ex = $highlighter->create_excerpt($hit);
                my $ex_title = $highlighter2->create_excerpt($hit);
                my $score = $hit->get_score;
                my $date = $hit->{date};
                my $id = $hit->{id};
                my $tid = $hit->{thread_id};
                my $bid = $hit->{board_id};
                my $author_id = $hit->{author_id};
                my $author_name = $hit->{author_name};
                if ($author_id) {
                    $uids{ $author_id } = 1;
                }
                my $score2 = ($score / $best) * 5 + 1;
                my $scores = [map { 'star' } 1 .. $score2/2];
                if ($score2 % 2) {
                    push @$scores, 'star_half';
                }
                my $msg = WWW::Poard::Model::Message::Readonly->new({
                    id => $id,
                    thread => WWW::Poard::Model::Thread::Readonly->new({
                        id => $tid,
                        board => $boards->{ $bid },
                        title => $ex_title,
                    }),
                    mtime => DateTime->from_epoch(epoch => $date),
                    author_id   => $author_id,
                    author_name => $author_name,
                    score => $score,
                    score_list => $scores,
                    message => $ex,
                });
                push @found, $msg;
                #print STDERR "$score: $hit->{title} #$id ($date) ($tid, $bid)\n";
            }
            if (keys %uids) {
                my $uschema = $self->schema->{user};
                my $usearch = $uschema->resultset('User')->search({
                        id  => { -in => [sort keys %uids] },
                    });
                while (my $user = $usearch->next) {
                    $uids{ $user->id } = $user->readonly([qw/ nick id /]);
                }
            }
            for my $msg (@found) {
                my $author_id = $msg->author_id;
                my $user = $uids{ $author_id };
                $msg->set_author($user);
            }

        }
        else {
            $search_term =~ s/[?%]//g;
            my $cond = {
                board_id => { 'IN' => $board_ids },
                -or => [
                    message => { 'LIKE' => '%'.$search_term.'%' },
                    'thread.title' => { 'LIKE' => '%'.$search_term.'%' },
                ],
                'me.status' => 'active',
                $in_thread
                ? (thread_id => $in_thread)
                : (),
            };
            my $conf = {
                order_by => 'ctime desc',
                join => 'thread',
            };
            $count = $schema->resultset('Message')->count($cond, $conf);
            $conf->{rows} = $rows;
            $conf->{page} = $page;
            my $search = $schema->resultset('Message')->search($cond,
                $conf,
            );
            my $boards = $self->fetch_boards($battie);
            while (my $msg = $search->next) {
                my $user;
                my $author_id = $msg->author_id;
                if ($author_id) {
                    $user = $battie->module_call(login => 'get_user_by_id', $author_id);
                }
                my $ro = $msg->readonly;
                $ro->set_author($user->readonly) if $user;
                my $thread = $msg->thread;
                my $thread_ro = $thread->readonly;
                $thread_ro->set_board($boards->{ $thread->board_id });
                $ro->set_thread($thread_ro);
                push @found, $ro;
            }
        }
        $data->{poard}->{found} = \@found;
        $data->{poard}->{search_term} = $search_term;
        my $pager = WWW::Battie::Pager->new({
                items_pp => $rows,
                # TODO
                total_count => $count,
                before => 3,
                after => 3,
                current => $page,
                link => $battie->self_url
                    . '/poard/search'
                    . '?p=%p;query='
                    . uri_escape_utf8($search_term)
#                    .';from=' . uri_escape_utf8($from)
                    . ($tid ? ";stid=$tid" : '')
                    . ($bid ? ";sbid=$bid" : '')
                    . ($by_date ? ';by_date=1' : '')
                    . ($rows ? ";rows=$rows" : '')
                    . ($in_title ? ';in_title=1' : ''),
                title => '%p',
            })->init;
        $data->{poard}->{pager} = $pager;
        #$data->{poard}->{search}->{from} = $from;
        if ($bid) {
            $data->{poard}->{search}->{sbid} = $bid;
            $data->{poard}->{search}->{board} = $board->readonly;
        }
        elsif ($tid) {
            $data->{poard}->{search}->{stid} = $tid;
            $data->{poard}->{search}->{thread} = $thread->readonly;
        }
        $data->{poard}->{search}->{where} = $where;
    }
    elsif ($search_type eq 'tag') {
        if (@more_args) {
            @tags = @more_args;
        }
        $data->{poard}->{search}->{type_tag} = 1;
        my @tags = $schema->resultset('Tag')->search({
                name => { IN => [@tags] },
            });
        $data->{poard}->{search}->{tags} = [map { $_->readonly } @tags];
        my @tag_ids = map { $_->id } @tags;
        $rows = 20;
        if (@tags) {
            my $cond = {
                board_id => { 'IN' => $board_ids },
                'thread_tags.tag_id' => { IN => [@tag_ids] },
                'me.status' => 'active',
            };
            my $conf = {
                order_by => 'ctime desc',
                join => 'thread_tags',
                group_by => 'me.id',
                select => [
                    qw/ id title board_id author_id author_name ctime /,
                    { count => 'id' },
                ],
                as => [qw/ id title board_id author_id author_name ctime tag_count /],
                # does not work (removes 'as tag_count' from SQL
#                having => [ tag_count => scalar @tags ],
                # do we do literal SQL here
                having => \[ 'count(me.id) = ?', [count => scalar @tags] ],
            };
            my $page = $request->pagenum(1000); # not more than 1000 pages;
            my $count;
            $count = $schema->resultset('Thread')->count($cond, $conf);
            $conf->{page} = $page;
            $conf->{rows} = $rows;
            my $search = $schema->resultset('Thread')->search($cond,
                $conf,
            );
            my $boards = $self->fetch_boards($battie);
            my @found;
            my %uids;
            while (my $thread = $search->next) {
                my $test = $thread->get_column('tag_count');
                my $ro = $thread->readonly([qw/ id title board_id board author_id author_name ctime /]);
                my $author_id = $thread->author_id;
                my $author_name = $thread->author_name;
                if ($author_id) {
                    $uids{ $author_id } = 1;
                }
                push @found, $ro;
            }
            if (keys %uids) {
                my $uschema = $self->schema->{user};
                my $usearch = $uschema->resultset('User')->search({
                        id  => { -in => [sort keys %uids] },
                    });
                while (my $user = $usearch->next) {
                    $uids{ $user->id } = $user->readonly([qw/ nick id /]);
                }
            }
            for my $thread (@found) {
                my $author_id = $thread->author_id;
                my $user = $uids{ $author_id };
                $thread->set_author($user);
            }
            $data->{poard}->{found} = \@found;
            my $qs_tags = join ';', map {
                "tag=" . uri_escape_utf8($_->name)
            } @tags;
            my $pager = WWW::Battie::Pager->new({
                    items_pp => $rows,
                    # TODO
                    total_count => $count,
                    before => 3,
                    after => 3,
                    current => $page,
                    link => $battie->self_url
                        . '/poard/search/tag'
                        . '?p=%p;'.$qs_tags,
#                        . ($tid ? ";stid=$tid" : '')
#                        . ($bid ? ";sbid=$bid" : '')
#                        . ($by_date ? ';by_date=1' : '')
#                        . ($rows ? ";rows=$rows" : '')
#                        . ($in_title ? ';in_title=1' : ''),
                    title => '%p',
                })->init;
            $data->{poard}->{pager} = $pager;
        }

    }
    my $options = $self->create_board_options($battie);
    unshift @$options, undef;
    if ($board) {
        $options->[0] = $bid;
    }
    $data->{poard}->{search}->{board_options} = $options;
}

sub create_board_options {
    my ($self, $battie) = @_;
    my $boards = $self->fetch_boards($battie);
    my @options;
    for my $board (sort { $a->get_lft <=> $b->get_lft } values %$boards) {
        next if $board->get_lft == 1;
        next unless $board->is_leaf;
        next unless $self->check_board_group($battie, $board);
        my $name = ('-' x $board->level) . ' ' . $board->name;
        push @options, [$board->id, $name];
    }
    return \@options;
}

sub poard__view_subscriptions {
    shift->poard__subscriptions(@_)
}
sub poard__subscriptions {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $boards = $self->fetch_boards($battie);
    my $notify = $schema->resultset('Notify')->search({
            user_id => $battie->session->userid,
        },
        {
            prefetch    => 'thread',
            order_by => 'thread.mtime desc',
        });
    my @subs;
    my @db_threads;
    while (my $sub = $notify->next) {
        my $ro = $sub->readonly;
        push @subs, $ro;
        push @db_threads, $sub->thread;
    }
    my $threads = $self->render_thread_headers($schema, $battie, \@db_threads);
    for my $i (0 .. $#subs) {
        my $ro = $subs[ $i ];
        my $thread_ro = $threads->[ $i ];
        my $board = $boards->{ $thread_ro->board_id };
        $thread_ro->set_board($board);
        $ro->set_thread($thread_ro);
    }
    my $data = $battie->get_data;
    $self->mark_read_threads($battie, $threads);
    $data->{poard}->{subscriptions} = \@subs;
}

sub fetch_subscription_ids {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $uid = $battie->session->userid or return [];
    my $sub_ids = $battie->from_cache("poard/subscription_ids/$uid");
    unless ($sub_ids) {
        $sub_ids = [];
        my $notify = $schema->resultset('Notify')->search({
                user_id => $uid,
            },
            {
                select => [qw/ thread_id /],
            });
        while (my $item = $notify->next) {
            push @$sub_ids, $item->thread_id;
        }
        $battie->to_cache("poard/subscription_ids/$uid", $sub_ids, 60 * 60 * 24 * 10);
    }
    return $sub_ids;
}

sub poard__msgs_by_nick {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    # TODO show unapproved messages for janitors
    my $page = $request->pagenum(1000); # not more than 1000 pages;
    my $rows = 100;
    my $cond = {
        'me.status' => 'active',
        'me.author_id' => $id,
    };
    my $count = $schema->resultset('Message')->count($cond);
    my $search = $schema->resultset('Message')->search(
        $cond,
        {
            order_by    => 'me.ctime desc',
            rows        => $rows,
            page        => $page,
            prefetch    => { thread => 'board' },
        },
    );
    my @msgs;
    my $last_thread_id = 0;
    my $last_thread;
    my @msgs_thread;
    my %allowed;
    while (my $msg = $search->next) {
        my $thread = $msg->thread;
        my $board = $thread->board;
        unless (exists $allowed{ $thread->id }) {
            unless ($self->check_board_group($battie, $board)) {
                $allowed{ $thread->id } = 0;
            }
            else {
                $allowed{ $thread->id } = 1;
            }
        }
        next unless $allowed{ $thread->id };
        my $thread_ro = $thread->readonly;
        my $board_ro = $board->readonly;
        $thread_ro->set_board($board_ro);
        my $ro = $msg->readonly([qw/ id ctime mtime position thread_id /]);
        $ro->set_thread($thread_ro);
        push @msgs, {
            is_new  => $last_thread_id != $thread->id,
            msg     => $ro,
        };
        $last_thread_id = $thread->id;
    }
    my $pager = WWW::Battie::Pager->new({
            items_pp => $rows,
            spread => 3,
            total_count => $count,
            current => $page,
            link => $battie->self_url
                . "/poard/msgs_by_nick/$id"
                . "?p=%p"
                ,
            title => '%p',
        })->init;
    $battie->get_data->{poard}->{pager} = $pager;
    my $data = $battie->get_data;
    $data->{poard}->{msgs} = \@msgs;
    $data->{poard}->{msgs_count} = $count;
    my $author = $battie->module_call(login => get_user_by_id => $id);
    $data->{poard}->{author} = $author->readonly;
}

sub get_toggle_board_map {
    my ($self, $request) = @_;
    my %toggle_cookie = $request->cookie('battie_poard_toggle');
    my $ids = $toggle_cookie{boards} || '';
    # list of hidden boards
    my %map; @map{
        grep { length $_ and not tr/0-9//c } split m/,/, $ids
    } = ();
    return \%map;
}

sub poard__toggle_board_view {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $board = $schema->resultset('Board')->find($id);
    my $data = $battie->get_data;
    # TODO
    #$self->check_visibility($battie, $thread);
    $battie->not_found_exception("Board '$id' is not visible by you", [])
        unless $self->check_board_group($battie, $board);
    my $map = $self->get_toggle_board_map($request);
    my $submit = $request->get_submit;
    my $cookie;
    if ($submit->{toggle_hide}) {
        $map->{$id} = 1;
        $cookie = $battie->response->add_cookie({
            -name => 'battie_poard_toggle',
            -value => {
                boards => join(',', keys %$map),
           },
           -expires => '+3M',
        });
        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$map], ['map']);
        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$cookie], ['cookie']);
    }
    elsif ($submit->{toggle_show}) {
        delete $map->{$id};
        $cookie = $battie->response->add_cookie({
            -name => 'battie_poard_toggle',
            -value => {
                boards => join(',', keys %$map),
           },
           -expires => '+3M',
        });
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$map], ['map']);
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$cookie], ['cookie']);
    }
    else {
        $self->exception("Argument", "Not enough arguments") unless @$args;
    }
    if ($cookie) {
        if ($request->param('is_ajax')) {
            $data->{main_template} = "poard/ajax.html";
            my $ov = $self->get_overview($battie, $board);
            my @sub_boards = @{ $ov->sub_boards || [] };
            $self->mark_read_threads($battie, [map { $_->latest || () } @sub_boards]);
            if ($submit->{toggle_show}) {
                $data->{poard}->{overview} = $ov;
            }
        }
        else {
            $battie->set_local_redirect("/poard/start");
        }
        return;
    }
}

sub poard__mod_view_thread_log {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    my $schema = $self->schema->{poard};
    my $thread = $self->check_existance($battie, Thread => $id);
    $self->check_visibility($battie, $thread);
    my $ro = $thread->readonly;
    my $logs = $battie->get_logs($thread, {
            actions => [ qw{
            poard/create_thread poard/solve_thread poard/edit_thread_title
            poard/edit_thread_tags
            poard/mod_split_thread poard/mod_close_thread poard/mod_delete_thread
            poard/mod_fix_thread poard/mod_move_thread } ],
        });
    $ro->set_logs([map {
        my $ro = $_->readonly;
        my $user = $battie->module_call(login => 'get_user_by_id', $ro->user_id);
        $ro->set_user($user->readonly) if $user;
        $ro;
    } @$logs]);
    my $data = $battie->get_data;
    $data->{thread} = $ro;
}

sub poard__mod_view_message_log {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    my $schema = $self->schema->{poard};
    my $msg = $self->check_existance($battie, Message => $id);
    my $ro = $msg->readonly;
    my $logs = $battie->get_logs($msg);
    $ro->set_logs([map {
        my $ro = $_->readonly;
        my $user = $battie->module_call(login => 'get_user_by_id', $ro->user_id);
        $ro->set_user($user->readonly) if $user;
        $ro;
    } @$logs]);
    my $data = $battie->get_data;
    $data->{msg} = $ro;
}

sub poard__view_message_log {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    my $schema = $self->schema->{poard};
    my $msg = $self->check_existance($battie, Message => $id);
    my $thread = $msg->thread;
    $self->check_visibility($battie, $thread);
    my @logs;
    my $allow = $battie->get_allow;
    if ($msg->changelog) {
        my $logs = $schema->resultset('MessageLog')->search({
                message_id  => $msg->id,
            },
            {
                order_by => 'log_id desc',
                rows => 100,
            });
        while (my $log = $logs->next) {
            my $ro = $log->readonly;
            my $action = $log->action;
            my $show_user = 0;
            if ($action eq 'edit_message') {
                $show_user = 1;
            }
            elsif ($action =~ m/delete_message/) {
                $show_user = 1;
                unless ($allow->can_do(poard => 'mod_delete_message')) {
                    next;
                }
            }
            elsif ($action eq 'approve_message') {
                $show_user = 1;
                unless ($allow->can_do(poard => 'approve_message')) {
                    $show_user = 0;
                }
            }
            else {
                next;
            }
            if ($show_user) {
                my $user = $battie->module_call(login => 'get_user_by_id', $log->user_id);
                $ro->set_user($user->readonly) if $user;
            }
            push @logs, $ro;
        }
    }
    my $data = $battie->get_data;
    $data->{poard}->{message_log} = \@logs;
}

sub poard__mod_view_message_diff {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    my $d1 = $request->param('d1');
    my $d2 = $request->param('d2');
    my $schema = $self->schema->{poard};
    my $msg = $self->check_existance($battie, Message => $id);
    my $data = $battie->get_data;
    my ($m1, $m2);
    if ($d1) {
        $m1 = $schema->resultset('ArchivedMessage')->search({
                msg_id  => $id,
                id      => $d1,
            })->single;
    }
    else {
        # get the last one
        $m1 = $schema->resultset('ArchivedMessage')->search({
                msg_id  => $id,
            }, {
                order_by    => 'ctime desc',
                rows        => 1,
            })->single;
    }
    unless ($m1) {
        $self->exception(Argument => "No diff available");
    }
    my $msg_ro = $msg->readonly;
    my $latest = $schema->resultset('ArchivedMessage')->new({
            id  => 0,
            msg_id  => $id,
            ctime   => $msg->mtime,
            message => $msg->message,
        })->readonly;

    if ($d2) {
        $m2 = $schema->resultset('ArchivedMessage')->search({
                msg_id  => $id,
                id      => $d2,
            })->single;
    }
    else {
        $m2 = $latest;

    }
    my @versions = map {
        $_->readonly([qw/ id  ctime /])
    } $schema->resultset('ArchivedMessage')->search({
            msg_id  => $id,
        }, {
            order_by    => 'ctime desc',
        })->all;
    unshift @versions, $latest;
    $d1 ||= $m1->id;
    $d2 ||= $m2->id;
    my $sel1 = [$d1, map { [$_->id, $_->ctime] } @versions];
    my $sel2 = [$d2, map { [$_->id, $_->ctime] } @versions];
    $data->{poard}->{versions} = \@versions;
    $data->{poard}->{versions_options1} = $sel1;
    $data->{poard}->{versions_options2} = $sel2;
    $data->{poard}->{msg} = $msg_ro;
    warn __PACKAGE__.':'.__LINE__.": $d1 <> $d2\n";
    if ($m2 && $string_diff) {
        my($old_diff, $new_diff) = String::Diff::diff_fully($m1->message, $m2->message);
        my %opts = (
            escape => sub {
                local $_ = $_[0];
                s/&/&amp;/g;
                s/</&lt;/g;
                s/>/&gt;/g;
                s/"/&quot;/g;
            s/\n/<br>/g;
                $_
            },
            remove_open     => '<del>',
            remove_close    => '</del>',
            append_open     => '<ins>',
            append_close    => '</ins>',
        );
        my $old_str = string_diff($old_diff, %opts);
        my $new_str = string_diff($new_diff, %opts);
        my $diff = [$old_str, $new_str];
        for (@$diff) {
        }
        $data->{poard}->{diff} = $diff;
    }
 
}

sub string_diff {
    my($diff, %opts) = @_;
    my $str = '';

    my $esc = $opts{escape};
    for my $parts (@{ $diff }) {
        if ($parts->[0] eq '-') {
            $str .= $opts{remove_open}. ($esc ? $esc->($parts->[1]) : 
            $parts->[1]) . $opts{remove_close};
        }
        elsif ($parts->[0] eq '+') {
            $str .= $opts{append_open}. ($esc ? $esc->($parts->[1]) : 
            $parts->[1]) . $opts{append_close};
        }
        else {
            $str .= $esc ? $esc->($parts->[1]) : $parts->[1];
        }
    }
    $str;
}
sub poard__mod_fix_thread {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    # TODO $battie->valid_token
    if ($submit->{fix} or $submit->{unfix}) {
        my $schema = $self->schema->{poard};
        my $thread = $schema->resultset('Thread')->find($id);
        $self->exception("Argument", "Thread '$id' does not exist") unless $thread;
        $self->check_visibility($battie, $thread);
        $thread->fixed($submit->{fix} ? 1 : 0);
        $thread->mtime(\'mtime');
        $thread->update;
        $battie->set_local_redirect("/poard/thread/$id");
        $battie->writelog($thread, $submit->{fix} ? 'fix' : 'unfix');
    }
}

sub poard__mod_close_thread {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    if ($submit->{open} or $submit->{close}) {
        $battie->require_token;
        my $schema = $self->schema->{poard};
        my $thread = $self->check_existance($battie, Thread => $id);
        $self->check_visibility($battie, $thread);
        $thread->closed($submit->{close} ? 1 : 0);
        $thread->update;
        $battie->set_local_redirect("/poard/thread/$id");
        $battie->writelog($thread, $submit->{open} ? 'open' : 'close');
        $thread->discard_changes;
        $self->delete_thread_cache($battie, $thread);
        $self->reset_thread_cache($battie, $thread);
    }
}

sub poard__statistic {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->request;
    my $args = $request->get_args;
    my ($show, @args) = @$args;
    my $schema = $self->schema->{poard};
    my $data = $battie->get_data;
    my $stat = $self->get_statistics;
    my $groups = $stat->{groups};
    my $rows = $stat->{rows};
    $data->{subtitle} = join " - ",
        $battie->translate("poard_statistics"),
        $battie->translate("poard_board");
    # only index certain statistics
    my $threads_condition = {
        status => 'active',
        'board.grouprequired' => [undef, 0],
    };
    if (! defined $show) {
        my $stats = $self->generate_stats($battie, $groups);
        my $years = $stats->{years};
        $data->{poard}->{by_year} = $years;

        $data->{poard}->{stat}->{count} = $stats->{totals};
        $data->{poard}->{detailed} = $stats->{by_messages};
        $data->{poard}->{more} = $stats->{more}
    }
    elsif ($show eq 'year' and $args[0] =~ m{^(\d{4})\z}) {
        my $year = $1;
        $data->{subtitle} = join " - ",
            $battie->translate("poard_statistics"),
            $year,
            $battie->translate("poard_board");
        my $stats = $self->generate_time_stats($battie, year => $year)->{months};
        $battie->not_found_exception("No data for year $year", []) unless keys %$stats;
        $data->{poard}->{by_month} = $stats;
        $data->{poard}->{year} = $year;
        $battie->crumbs->append("Statistics", "poard/statistic");
        $battie->crumbs->append($year, "poard/statistic/year/$year");
        $data->{poard}->{breadcrumb} = [
            { title => $year, },
        ];
    }
    elsif ($show eq 'month' and $args[0] =~ m{^(\d{4})-(\d{2})\z}) {
        my ($year, $month) = ($1, $2);
        $data->{subtitle} = join " - ",
            $battie->translate("poard_statistics"),
            "$year-$month",
            $battie->translate("poard_board");
        my $stats = $self->generate_time_stats($battie, year => $year)->{days};
        $battie->not_found_exception("No data for month $month", [])
            unless exists $stats->{$month};
        $data->{poard}->{by_day} = $stats->{$month};
        $data->{poard}->{month} = "$year-$month";
        $battie->crumbs->append("Statistics", "poard/statistic");
        $battie->crumbs->append($year, "poard/statistic/year/$year");
        $battie->crumbs->append("$month", "poard/statistic/month/$year-$month");
        $data->{poard}->{breadcrumb} = [
            { title => $year,          link => "year/$year" },
            { title => "$year-$month", },
        ];
    }
    elsif ($show eq 'day' and $args[0] =~ m{^(\d{4})-(\d{2})-(\d{2})\z}) {
        my ($year, $month, $day) = ($1, $2, $3);
        $data->{subtitle} = join " - ",
            $battie->translate("poard_statistics"),
            "$year-$month-$day",
            $battie->translate("poard_board");
        my $stats = $self->generate_time_stats($battie, year => $year)->{days}->{$month}->{$day};
        $battie->not_found_exception("No data for day '$year-$month-$day'") unless $stats;
        my $search = $schema->resultset('Thread')->search(
            {
                %$threads_condition,
                'me.ctime' => { 'like' => "$year-$month-$day%" },
            },
            {
                join => 'board',
                order_by => 'me.ctime asc',
            },
        );
        my @threads;
        while (my $t = $search->next) {
            push @threads, $t->readonly;
        }
        $data->{poard}->{day} = "$year-$month-$day";
        $data->{poard}->{breadcrumb} = [
            { title => $year,          link => "year/$year" },
            { title => "$year-$month", link => "month/$year-$month" },
            { title => "$year-$month-$day" },
        ];
        $battie->crumbs->append("Statistics", "poard/statistic");
        $battie->crumbs->append($year, "poard/statistic/year/$year");
        $battie->crumbs->append("$month", "poard/statistic/month/$year-$month");
        $battie->crumbs->append("$day", "poard/statistic/day/$year-$month-$day");
        $data->{poard}->{threads} = \@threads;
    }
    elsif ($show =~ m/^(\d+|most)\z/) {
        my $count = $1;
        $battie->response->set_no_index(1);
        $battie->response->set_no_archive(1);
        my $from = -1;
        if ($count eq 'most') {
            $from = $groups->[-1];
            $count = undef;
        }
        else {
            for my $i (1 .. $#$groups) {
                if ($groups->[$i] == $count) {
                    $from = $groups->[$i-1];
                    last;
                }
            }
            if ($from == -1) {
                $count = $groups->[0];
            }
        }
        my $page = $request->pagenum(1000); # not more than 1000 pages;
        my $condition = {
            %$threads_condition,
            -and => [
                messagecount => { '>' => $from },
                defined $count
                ? (messagecount => { '<=' => $count })
                : (),
            ],
        };
        my $total = $schema->resultset('Thread')->count($condition, { join => 'board' });
        my $search = $schema->resultset('Thread')->search(
                $condition,
            {
                join => 'board',
                order_by => 'me.ctime desc',
                rows => $rows,
                page => $page,
            },
        );
        my @threads;
        while (my $t = $search->next) {
            push @threads, $t->readonly;
        }
        $data->{poard}->{threads} = \@threads;
        my $pager = WWW::Battie::Pager->new({
                items_pp => $rows,
                spread => 3,
                total_count => $total,
                current => $page,
                link => $battie->self_url
                    . "/poard/statistic/"
                    . (defined $count ? $count : 'most')
                    . "?p=%p"
                    ,
                title => '%p',
            })->init;
        $battie->get_data->{poard}->{pager} = $pager;
    }
    else {
        $battie->response->set_no_index(1);
        $battie->response->set_no_archive(1);
    }
}

sub generate_stats {
    my ($self, $battie, $groups) = @_;
    my $schema = $self->schema->{poard};
    my $stats = $battie->from_cache("poard/statistics");
    unless ($stats) {
        {
            my $search = $schema->resultset('Thread')->search(
                { status => 'active' },
                {
                    group_by => \'SUBSTR(ctime, 1, 4)',
                    select => [
                        \'SUBSTR(ctime, 1, 4)',
                        { count => 'id' },
                    ],
                    as => [qw/ title id /],
                    order_by => \'SUBSTR(ctime, 1, 4)',
                },
            );
            my %years;
            while (my $group = $search->next) {
                my $year = $group->title;
                my $count = $group->id;
                $years{$year}->{threads} = $count;
            }
            my $search2 = $schema->resultset('Message')->search(
                { status => 'active' },
                {
                    group_by => \'SUBSTR(ctime, 1, 4)',
                    select => [
                        \'SUBSTR(ctime, 1, 4)',
                        { count => 'id' },
                    ],
                    as => [qw/ author_name id /],
                    order_by => \'SUBSTR(ctime, 1, 4)',
                },
            );
            while (my $group = $search2->next) {
                my $year = $group->author_name;
                my $count = $group->id;
                $years{$year}->{msgs} = $count;
            }
            $stats->{years} = \%years;
        }

        {
            my $search = $schema->resultset('Thread')->search(
                { status => 'active' },
                {
                    select => [
                        { sum => 'messagecount' },
                        { count => 'id' },
                    ],
                    as => [qw/ messagecount id /],
                },
            );
            my $last_group = -1;
            my (%stats, $thread_count, $answer_count, $ms_count, $more);
            my @stats;
            for my $group ((sort { $a <=> $b } @$groups), undef) {
                my $search_l = $search->search({
                    -and => [
                        messagecount => { '>' => $last_group },
                        defined $group
                        ? (messagecount => { '<=' => $group })
                        : (),
                    ],
                });
                # only one row - SUM and COUNT
                if (my $thread = $search_l->next) {
                    no warnings 'uninitialized';
                    $answer_count += $thread->messagecount;
                    $ms_count += $thread->id + $thread->messagecount;
                    $thread_count += $thread->id;
                    if (defined $group) {
                        push @stats, {
                            group => [$last_group, $group],
                            threads => $thread->id,
                        };
                        $stats{$group} += $thread->id;
                    }
                    else {
                        $more += $thread->id;
                    }
                }
                $last_group = $group;
            }


            $stats->{by_messages} = \@stats;
            $stats->{more} = $more;
            $stats->{totals} = {
                threads => $thread_count,
                answers   => $answer_count,
                messages => $ms_count,
            };
        }

        $battie->to_cache("poard/statistics", $stats, 60 * 60 * 12);
    }
    return $stats;
}


sub generate_time_stats {
    my ($self, $battie, %args) = @_;
    if (my $year = $args{year}) {
        my $stats = $battie->from_cache("poard/stats/year/$year");
        unless ($stats) {
            my $schema = $self->schema->{poard};
            my $search = $schema->resultset('Thread')->search(
                {
                    status => 'active',
                    ctime => { 'like' => "$year%" },
                },
                {
                    group_by => \'SUBSTR(ctime, 6, 5)',
                    select => [
                        \'SUBSTR(ctime, 6, 5)',
                        { count => 'id' },
                    ],
                    as => [qw/ title id /],
                    order_by => \'SUBSTR(ctime, 6, 5)',
                },
            );
            my %months;
            my %days;
            while (my $group = $search->next) {
                my $day = $group->title;
                (my $month, $day) = $day =~ m/(\d{2})-(\d{2})/ or next;
                my $count = $group->id;
                $months{$month}->{threads} += $count;
                $days{$month}->{$day} = { threads => $count };
            }

            my $search2 = $schema->resultset('Message')->search(
                {
                    status => 'active',
                    ctime => { 'like' => "$year%" },
                },
                {
                    group_by => \'SUBSTR(ctime, 6, 5)',
                    select => [
                        \'SUBSTR(ctime, 6, 5)',
                        { count => 'id' },
                    ],
                    as => [qw/ author_name id /],
                    order_by => \'SUBSTR(ctime, 6, 5)',
                },
            );
            while (my $group = $search2->next) {
                my $day = $group->author_name;
                (my $month, $day) = $day =~ m/(\d{2})-(\d{2})/ or next;
                my $count = $group->id;
                $months{$month}->{msgs} += $count;
                $days{$month}->{$day}->{msgs} = $count;
            }

            $stats = { days => \%days, months => \%months };
            # TODO
            my $current_year = (gmtime)[5] + 1900;
            my $cache_time = 60 * 60 * 12;
            if ($year < $current_year) {
                $cache_time = 60 * 60 * 24 * 7;
            }
            if (keys %months) {
                $battie->to_cache("poard/stats/year/$year", $stats, $cache_time);
            }
        }
        return $stats;
    }
}


sub set_message_edit_status {
    my ($self, $battie, $msg) = @_;
    my $is_mod = $battie->get_allow->can_do(poard => 'mod_edit_message');
    my $editable = 0;
    if ($is_mod) {
        $editable = 1;
    }
    elsif ($msg->author_id and $battie->get_session->userid) {
        $editable = $msg->author_id == $battie->get_session->userid;
    }
    $msg->set_is_editable($editable);
}

sub render_message {
    my ($self, $battie, $message, $type, $with_author, $readmore, $attachments, $params) = @_;
    $with_author = 1 unless defined $with_author;
    my $schema = $self->schema->{poard};
    my $uschema = $self->schema->{user};
    my $ro = $message->readonly;

    $type ||= 'html';
    if ($type eq 'html') {
        my $msid = $ro->id;
        my $more = $readmore ? 1 : undef;
        my $re = $battie->get_render->render_message_html($ro->message, $msid, $more, $params);
        $ro->set_rendered($re);
        $ro->set_message('');
    }
    elsif ($type eq 'none') {
        $ro->set_message('');
    }

    $ro->set_is_editable(1) if $battie->get_allow->can_do(poard => 'mod_edit_message');
    if ($battie->get_session->userid and ($message->author_id || 0) == $battie->get_session->userid) {
        # view own message
#        $ro->set_status('active') if $ro->status ne 'deleted';
        $ro->set_is_editable(1);
    }

    if ($attachments) {
        my $dirs = join '/', $message->id =~ m/(\d{1,3})/g;
        my $conf = $self->get_attachment;
        my $thumb_dir = $conf->{thumbdir};
        $thumb_dir = $battie->get_paths->{docurl} . "/$thumb_dir";
        my @ro;
        for my $attach (@$attachments) {
            my $ro = $attach->readonly([qw/ attach_id meta size thumb type filename message_id /]);
            if ($attach->thumb) {
                my $attach_id = $attach->attach_id;
                my (undef, $itype) = split m{/}, $attach->type;
                my $path = "$thumb_dir/$dirs/thumb_$attach_id.$itype";
                $ro->set_thumbnail_url($path);
            }
            push @ro, $ro;
        }
        $ro->set_attachments(\@ro);
    }
    return $ro unless $with_author;
    if ($message->approved_by) {
        my $approver = $battie->module_call(login => 'get_user_by_id', $message->approved_by);
        $ro->set_approved_by($approver->readonly([qw/ id nick /])) if $approver;
    }
    if ($message->author_id) {

        my $user = $uschema->resultset('User')->search(
            { id => $message->author_id},
            {
                prefetch => [qw/ profile settings /],
                'select' => [qw/ me.id me.nick me.ctime profile.homepage profile.avatar profile.signature /],
            })->single;
        return $ro unless $user;
        $self->render_msg_author($battie, $ro, $user, $type);
    }
    else {
        $ro->set_author_name($message->author_name);
    }
    return $ro;
}

sub render_author {
    my ($self, $battie, $user, $type) = @_;
    my $user_ro = $user->readonly([qw/ id group_id nick ctime openid / ]);
    my $settings = $user->settings;
    my $profile = $user->profile;
    if ($settings) {
        $user_ro->set_settings($settings->readonly([qw/ messagecount /]));
    }
    if ($profile) {
        my $profile_ro = $profile->readonly([qw/ homepage avatar user_id /]);
        $user_ro->set_profile($profile_ro);
        if ($type eq 'html') {
            my $re_sig = $battie->get_render->render_message_html($profile->signature);
            $profile_ro->set_rendered_sig($re_sig);
        }
    }
    return $user_ro;
}

sub msg_author {
    my ($self, $ro, $user_ro) = @_;
    if (my $p = $user_ro->profile) {
        my $sig = $p->rendered_sig;
#        $ro->set_rendered_sig($sig);
    }
    $ro->set_author($user_ro);
}

sub render_msg_author {
    my ($self, $battie, $ro, $user, $type) = @_;
    my $user_ro = $self->render_author($battie, $user, $type);
    $self->msg_author($ro, $user_ro);
}


sub render_subtrees {
    my ($self, $thread) = @_;
    my $meta = $thread->meta;
    if ($meta and my $subtrees = $meta->{subtrees}) {
        my @subs;
        for my $id (keys %$subtrees) {
            $subtrees->{$id}->{children} = $subtrees->{$id}->{count};
        }
        for my $id (keys %$subtrees) {
            my $s = $subtrees->{$id};
            if (my $parent = $s->{parent}) {
                $subtrees->{ $parent }->{children} -= $s->{count};
            }
        }
        my @children = $self->subtree_children($subtrees, 0, 0);
        for my $child (@children) {
            my $id = $child->{id};
            my $s = $subtrees->{$id};
            my $title = $s->{title};
            $title = $thread->title unless defined $title;
            push @subs, {
                id      => $id,
                mtime   => $s->{mtime},
                title   => $title,
                count   => $s->{count},
                level   => $child->{level},
                children => $s->{children},
            };
        }
        shift @subs;
        $thread->set_subtrees(\@subs) if @subs;
    }
}

sub subtree_children {
    my ($self, $subtrees, $id, $level) = @_;
    $id ||= 0;
    my @children = map {
        ($subtrees->{$_}->{parent} || 0) == $id
            ? { tree => $subtrees->{$_}, level => $level, id => $_ }
            : ()
    } sort { $a <=> $b } keys %$subtrees;
    my @children2;
    for my $child (@children) {
        push @children2, $child;
        push @children2, $self->subtree_children($subtrees, $child->{id}, $level + 1);
    }
    return @children2;
}

sub latest_threads {
    my ($self, $schema, $battie, $search) = @_;
    my @db_threads;
    while (my $thread = $search->next) {
        push @db_threads, $thread;
    }
    my $threads = $self->render_thread_headers($schema, $battie, \@db_threads);
    return $threads;
}

use constant CACHE_THREAD_HEADER => 60 * 60 * 24 * 40;
sub render_thread_headers {
    my ($self, $schema, $battie, $db_threads) = @_;
    my @threads;
    my %uids;
    my @msgs;
    my %readers;
    my @unfinished_threads;
    for my $thread (@$db_threads) {
        my $tid = $thread->id;
        my $ck = "poard/thread_header/$tid";
        my $cached_thread = $battie->from_cache($ck);
        if ($cached_thread) {
            push @threads, $cached_thread;
            next;
        }
        $readers{ $thread->id } = 0;
        my $thread_ro = $thread->readonly([qw/ id author_id author_name is_tree status fixed is_survey meta messagecount ctime mtime closed solved title board_id /]);
        $self->render_subtrees($thread_ro) if ($thread->is_tree);
        my $author_id = $thread->author_id;
        if ($author_id) {
            $uids{ $author_id } = undef;
        }
        my $last = $thread->search_related('messages',
            {
                position => { '>' , 0 },
                status => 'active',
            }, {
                order_by => 'position desc',
                rows => 1,
            })->single;
        if ($last) {
            my $last_ro = $last->readonly([qw/ id author_name author_id status ctime mtime position /]);
#            my $last_ro = $self->render_message($battie, $last, 'none', 0);
            $thread_ro->set_last($last_ro);
            if ($last_ro->author_id) {
                push @msgs, $last_ro;
                $uids{ $last_ro->author_id } = undef if $last_ro->author_id;
            }
            $self->_times_for_cache($last_ro);
        }
        my $lctime = $last ? $last->ctime : $thread->ctime;
        if ($lctime == $thread_ro->mtime) {
            $thread_ro->set_mtime(undef);
        }
        $self->_times_for_cache($thread_ro);
        push @threads, $thread_ro;
        push @unfinished_threads, $thread_ro;
    }

    if (keys %uids) {
        $self->fetch_user_infos($battie, \%uids);
        my @left = grep { not $uids{ $_ } } keys %uids;
        if (@left) {
            my $users = $battie->module_call(login => 'get_user_by_id', [@left]);
            for my $user (@$users) {
                $uids{$user->id} = $user->readonly([qw/ nick id /]);
            }
        }
    }
    for my $user (values %uids) {
        next unless $user;
        $user->set_profile(undef);
        $user->set_settings(undef);
        $user->set_ctime(undef);
    }
    if (keys %readers) {
        $self->_fetch_thread_readers($battie, $schema, \%readers);
    }
    for my $thread (@unfinished_threads) {
        $thread->set_readers($readers{ $thread->get_id });
        my $author_id = $thread->author_id or next;
        my $user = $uids{ $author_id };
        $thread->set_author($user);
    }
    for my $msg (@msgs) {
        my $author_id = $msg->author_id;
        if ($author_id) {
            my $user = $uids{ $author_id };
            $msg->set_author($user);
        }
        my $approved = $msg->approved_by;
        if ($approved) {
            my $user = $uids{ $author_id };
            $msg->set_approved_by($user);
        }
    }
    for my $thread (@unfinished_threads) {
        my $tid = $thread->id;
        my $ck = "poard/thread_header/$tid";
        my $readers = $thread->readers;
        $battie->to_cache($ck, $thread, time + CACHE_THREAD_HEADER);
    }
    return \@threads;
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

sub _fetch_thread_readers {
    my ($self, $battie, $schema, $readers) = @_;
    my @ids = keys %$readers;
    my $search = $schema->resultset('ReadMessages')->search({
            thread_id => { IN => [@ids] },
        },
        {
            group_by => 'me.thread_id',
            select => [
                qw/ thread_id /,
                { count => 'user_id' },
            ],
            as => [qw/ thread_id readers /],
        });
    while (my $item = $search->next) {
        my $count = $item->get_column('readers');
        my $thread_id = $item->thread_id;
        $readers->{ $thread_id } = $count;
    }
}

sub latest_messages {
    my ($self, $battie, $search, $render) = @_;
    my @msgs;
    my %uids;
    my $renderer = $battie->get_render;
    my $render_code = $render eq 'html' ? 'render_message_html' : 'render_message_text';
    my $boards = $self->fetch_boards($battie);
    while (my $msg = $search->next) {
        my $msg_ro = $msg->readonly([qw/
            id author_id author_name message thread_id status
            position
            /]);
        my $m = $msg->get_column('mtime_string');
        $m =~ s/ /T/;
        $msg_ro->set_mtime($m);
        my $author_id = $msg->author_id;
        if ($author_id) {
            $uids{ $author_id } = undef;
        }
        my $re = $renderer->$render_code($msg_ro->message, $msg_ro->id);
        $msg_ro->set_rendered($re);
        $msg_ro->set_message(undef);
        my $thread = $msg->thread;
        my $thread_ro = $thread->readonly([qw/ title id /]);
        my $board = $boards->{ $thread->board_id };
        $thread_ro->set_board($board);
        $msg_ro->set_thread($thread_ro);
        push @msgs, $msg_ro;
    }
    $self->fetch_user_infos($battie, \%uids);
    for my $user (values %uids) {
        $user->set_settings(undef);
        $user->set_profile(undef);
        $user->set_ctime(undef);
    }
    for my $msg (@msgs) {
        my $author_id = $msg->author_id or next;
        $msg->set_author($uids{ $author_id });
    }
    return \@msgs;
}

use constant CACHE_RSS_TIME => 60 * 60 * 2;
use constant CACHE_RSS_CHECK => 60 * 5;
sub poard__xml_messages_rss {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $battie->response->set_needs_navi(0);
    my $args = $request->get_args;
    my ($bid) = @$args;
#    my $board = $bid ? $self->check_existance($battie, Board => $bid) : undef;
#    $battie->not_found_exception("Board '$bid' is not visible by you", [])
#        if ($board and not $self->check_board_group($battie, $board));
    my $ck = "poard/rss_messages2/";
    $ck .= ($bid || 0);

    my $boards = $self->fetch_boards($battie);
    my @allowed = $self->check_board_group($battie, values %$boards);
    my %boards = map { $_->id => 1 } @allowed;
    my %cond;
    if ($bid) {
        unless ($boards{ $bid }) {
            $battie->not_found_exception("Board does not exist");
        }
        $cond{'thread.board_id'} = $bid;
    }
    else {
        $cond{'thread.board_id'} = { IN => [keys %boards] };
    }
    my $board = $bid ? $boards->{ $bid } : undef;
    my $cached = $battie->from_cache($ck);
    my $now = time;
    if ($cached and (($cached->{fetched} + CACHE_RSS_CHECK) < $now)) {
        $self->init_db($battie);
        my $schema = $self->schema->{poard};
        # outdated, see if there are new messages
        my $count = $schema->resultset('Message')->count({
            %cond,
            'me.status' => 'active',
            'me.ctime' => { '>=', DateTime->from_epoch( epoch => $cached->{fetched} ) },
        }, {
            join => 'thread',
        });
#        warn __PACKAGE__.':'.__LINE__.": $count new messages\n";
        if ($count > 0) {
            undef $cached;
        }
        else {
            $cached->{fetched} = $now;
            $battie->to_cache($ck, $cached, CACHE_RSS_TIME);
        }
    }
    unless ($cached) {
        $self->init_db($battie);
        my $schema = $self->schema->{poard};
        my $search = $schema->resultset('Message')->search(
            {
                'me.status' => 'active',
                'me.ctime' => { '>', DateTime->now->subtract( days => 7 ) },
                %cond,
            },
            {
                order_by => 'me.ctime desc',
                rows => 100,
                prefetch    => 'thread',
                select => [qw/
                    me.id me.author_id me.author_name me.message
                    me.thread_id me.status me.mtime me.position
                    thread.id thread.title
                /],
                as => [qw/
                    me.id me.author_id me.author_name me.message
                    me.thread_id me.status mtime_string me.position
                    thread.id thread.title
                /],
            },
        );
        my $cmsgs = $self->latest_messages($battie, $search, 'text');
        $cached = {
            msgs => $cmsgs,
            fetched => $now,
        };
        $battie->to_cache($ck, $cached, CACHE_RSS_TIME);
    }
    else {
        $self->load_db($battie);
    }
    my $msgs = $cached->{msgs};
    my $data = $battie->get_data;
    my $max = $self->get_max_length_rss_msg;
    my $type = $request->param('type') || 'abstracts';
    #my %boards = map {
    map {
        my $text = $_->rendered;
        if ($type eq 'abstracts' and length $text > $max) {
            $text = substr($text, 0, $max-3) . '...';
        }
        $text =~ s/&/&amp;/g;
        $text =~ s/</&lt;/g;
        $text =~ s/>/&gt;/g;
        $text =~ s/"/&quot;/g;
        $text =~ s/\r?\n/<br>/g;
        $_->set_rendered($text);
    } @$msgs;

    # send only messages newer than requested
    my $since = $battie->request->get_if_modified_since;
    if ($since) {
#        warn __PACKAGE__.':'.__LINE__.": if modified since $since\n";
        @$msgs = grep {
            my $mtime = $_->mtime;
            $mtime gt $since
        } @$msgs;
    }

    if ($type eq 'full' and @$msgs > 25) {
        @$msgs = @$msgs[0 .. 29];
    }
    my $latest = $msgs->[0];
    my $response = $battie->response;
    $response->set_content_type('application/rss+xml');
    if ($latest) {
        my $ltime = $latest->mtime;
        $response->set_last_modified($ltime);
        if ($battie->request->is_mtime_satisfying($ltime)) {
            $response->set_status('304 Not modified');
            return;
        }
    }
    elsif ($since) {
        $response->set_status('304 Not modified');
        return;
    }
    $data->{poard}->{messages} = $msgs;
    $data->{poard}->{title} = $self->get_rss_title;
    $data->{poard}->{title} .= ' - Board ' . $board->name if $bid;
}

my %last_mtime_boards;
sub fetch_boards {
    my ($self, $battie, $board_id) = @_;
    my $lcache = $self->get_lcache->{board_list};
    # cache board list in memory
    if ($lcache) {
        if ($lcache->{time} > time - 60) {
            return $lcache->{data}->{ $board_id } if $board_id;
            return $lcache->{data};
        }
        my $last_mtime = $last_mtime_boards{ $battie } || 0;
        my $mtime = $battie->from_cache('poard/board_list_mtime');
        unless ($mtime) {
            $mtime = time;
            warn __PACKAGE__.':'.__LINE__.": poard/board_list_mtime = $mtime\n";
            $battie->to_cache_add('poard/board_list_mtime', $mtime, 60 * 60 * 24);
        }
        if ($mtime > $last_mtime) {
            warn __PACKAGE__.':'.__LINE__.": BOARDS HAVE CHANGED! ($mtime > $last_mtime)\n";
            delete $lcache->{data};
            $last_mtime_boards{ $battie } = $mtime;
        }
        else {
            $lcache->{time} = time;
            return $lcache->{data}->{ $board_id } if $board_id;
            return $lcache->{data};
        }
    }
    my $now = time;
    my $boards = $battie->from_cache('poard/board_list');
    $self->load_db($battie);
    unless ($boards) {
        $self->init_db($battie);
        my $schema = $self->schema->{poard};
        my $last_level = 1;
        my $RGT;
        my @l;
        my %boards;
        for my $board ($schema->resultset('Board')->search({},{order_by=>'lft'})->all) {
            my $last = 1;
            my $ro = $board->readonly([qw/ id name grouprequired lft rgt flags /]);
            my ($lft, $rgt) = ($board->lft, $board->rgt);

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
                    $last = 0 if @l && ($rgt + 1 < $l[-1]);
                    push @l, $rgt;
                }
            }
            else {
                @l = $rgt;
            }
            $ro->set_level($#l);


            $RGT = $rgt;
            $last_level = @l;


            $boards{ $board->id } = $ro;
        }
        $boards = \%boards;
        my @parent_ids;
        for my $id (sort { $boards->{ $a }->get_lft <=> $boards->{ $b }->get_lft } keys %$boards) {
            my $board = $boards->{ $id };
            my $level = $board->level + 1;
            if ($level > @parent_ids) {
                $board->set_parent_ids([@parent_ids]);
                push @parent_ids, $id;
            }
            elsif ($level <= @parent_ids) {
                my $diff = @parent_ids - $level + 1;
                pop @parent_ids for (1 .. $diff);
                $board->set_parent_ids([@parent_ids]);
                push @parent_ids, $id;
            }
        }
        $battie->to_cache('poard/board_list', $boards, 60 * 60 * 24);
    }
    $self->get_lcache->{board_list} = { data => $boards, time => $now };
    $last_mtime_boards{ $battie } = $now;
    return $boards->{ $board_id } if $board_id;
    return $boards;
}


sub poard__view_trash {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $response = $battie->response;
    $response->set_no_cache(1);
    $self->init_db($battie);
    my $args = $request->get_args;
    my $data = $battie->get_data;
    my $schema = $self->schema->{poard};
    if (@$args) {
        my ($type) = @$args;
        if ($type eq 'messages') {
            my $search = $schema->resultset('Trash')->search(
                {
                    msid => { '>' => 0 },
                },
                {
                    order_by => 'mtime desc',
                }
            );
            my @trash;
            while (my $trash = $search->next) {
                push @trash, $trash;
            }
            $self->render_trash(\@trash, 'messages');
            $data->{poard}->{trash_list}->{messages} = \@trash;
        }
        elsif ($type eq 'threads') {
            my $search = $schema->resultset('Trash')->search(
                {
                    thread_id => { '>' => 0 },
                },
                {
                    order_by => 'mtime desc',
                }
            );
            my @trash;
            while (my $trash = $search->next) {
                push @trash, $trash;
            }
            $self->render_trash(\@trash, 'threads');
            $data->{poard}->{trash_list}->{threads} = \@trash;
        }
    }
    else {
        my $msg_count = $schema->resultset('Trash')->count({
                msid => { '>' => 0 },
            });
        my $thread_count = $schema->resultset('Trash')->count({
                thread_id => { '>' => 0 },
            });
        $data->{poard}->{trash}->{msg_count} = $msg_count;
        $data->{poard}->{trash}->{thread_count} = $thread_count;
    }
    $data->{subtitle} = "Board - Deleted Articles";
}

sub render_trash {
    my ($self, $trashlist, $type) = @_;
    my $schema = $self->schema->{poard};
    my %uids;
    if ($type eq 'messages') {
        my %ids;
        for my $trash (@$trashlist) {
            my $trash_ro = $trash->readonly;
            $trash = $trash_ro;

            my $msid = $trash->msid;
            push @{ $ids{ $msid } }, $trash;

            my $uid = $trash->deleted_by;
            push @{ $uids{$uid} }, $trash;
        }
        my @msgs = $schema->resultset('Message')->search({ id => [keys %ids] })->all;
        for my $msg (@msgs) {
            my $list = $ids{$msg->id};
            my $msg_ro = $msg->readonly;
            $_->set_message($msg_ro) for @$list;
        }
    }
    elsif ($type eq 'threads') {
        my %ids;
        for my $trash (@$trashlist) {
            my $trash_ro = $trash->readonly;
            $trash = $trash_ro;

            my $tid = $trash->thread_id;
            push @{ $ids{ $tid } }, $trash;

            my $uid = $trash->deleted_by;
            push @{ $uids{$uid} }, $trash;
        }
        my @threads = $schema->resultset('Thread')->search({ id => [keys %ids] })->all;
        for my $thread (@threads) {
            my $list = $ids{$thread->id};
            my $thread_ro = $thread->readonly;
            $_->set_thread($thread_ro) for @$list;
        }
    }
    my $uschema = $self->schema->{user};
    my @users = $uschema->resultset('User')->search({ id => [keys %uids] })->all;
    for my $user (@users) {
        my $list = $uids{$user->id};
        my $user_ro = $user->readonly;
        $_->set_user($user_ro) for @$list;
    }
    return $trashlist;
}

sub poard__view_latest {
    shift->poard__latest(@_)
}

sub poard__latest {
    my ($self, $battie) = @_;
    my $request = $battie->request;

    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($time) = @$args;
    my $interval = $time eq '24h' ? 1 : $time eq '7d' ? 7 : '';
    my $cache_key = $time eq '24h' ? '24' : $time eq '7d' ? '7d' : '';
    my ($threads, $mtime) = $battie->from_cache('poard/latest' . $cache_key);
    my $response = $battie->response;

    unless ($threads) {
        $self->init_db($battie);
        my $schema = $self->schema->{poard};
        my $minus = DateTime->now->subtract(days => $interval);
        my $search = $schema->resultset('Thread')->search(
            {
                'me.mtime' => { '>=', $minus },
                'me.status' => { '!=' => 'deleted' },
            },
            {
                order_by => 'me.mtime desc',
            },
        );
        my $cthreads = $self->latest_threads($schema, $battie, $search);
        $threads = $cthreads;
        $battie->to_cache('poard/latest' . $cache_key, $threads, 11 * 60);
    }
    else {
        $self->load_db($battie);
    }

    my $boards = $self->fetch_boards($battie);

    my $data = $battie->get_data;
    $self->mark_read_threads($battie, $threads);
    my %boards = map { $_->board_id => $boards->{ $_->board_id } } @$threads;
    my @allowed = $self->check_board_group($battie, values %boards);
    %boards = map { $_->id => 1 } @allowed;
    @$threads = grep { $boards{ $_->board_id } } @$threads;
    map {
        $_->set_board($boards->{ $_->board_id });
    } @$threads;
    if (my $hide = $data->{settings}->{poard}->{overview}->{hidden}) {
        my %hidden_threads;
        my %hidden = map { $_ => 1 } split m/,/, $hide;
        @$threads = grep {
            my $show = 1;
            if ($hidden{ $_->board_id }) {
                $hidden_threads{ $_->board_id }->{name} ||= $_->board->name;
                $hidden_threads{ $_->board_id }->{id} ||= $_->board_id;
                $hidden_threads{ $_->board_id }->{count}++;
                $show = 0;
            }
            $show
        } @$threads;
        $data->{poard}->{hidden_threads} = [ map {
                $hidden_threads{ $_ }
            } sort {
                $hidden_threads{ $a }->{name} cmp $hidden_threads{ $b }->{name}
            } keys %hidden_threads
        ];
    }
#    my $profile = $battie->fetch_settings('ro');
#    my $settings = $profile ? $profile->meta : {};
    my $settings = $battie->fetch_settings('cache');
    if ($settings->{poard}->{overview}->{show_subs}) {
        my $sub_ids = $self->fetch_subscription_ids($battie);
        my %hash;
        @hash{ @$sub_ids } = ();
        for my $thread (@$threads) {
            if (exists $hash{ $thread->id }) {
                $thread->set_subscribed(1);
            }
        }

    }
    $data->{poard}->{threads} = $threads;
    if ($battie->allow->can_do(poard => 'show_unapproved_messages')) {
        # show messages to approve
        my $onhold = $self->get_onhold($battie);
        $data->{poard}->{onhold} = $onhold;
    }
    my $recent = $battie->translate("poard_recent_articles");
    $data->{subtitle} = join " - ",
        $recent,
        $battie->translate("poard_board");
    my $pi = $request->get_path_info;
    $pi =~ s#^/##;
    $battie->crumbs->append($recent, $pi);
    $data->{poard}->{latest_time} = $time;
}

sub mark_read_threads {
    my ($self, $battie, $list) = @_;
    return unless $battie->session->get_user;
    return unless @$list;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my @ids = map { $_->id } @$list;
    my @cache_keys;
    my $uid = $battie->session->userid;
    for my $tid (@ids) {
        my $ck = "poard/read_thread/$uid/$tid";
        push @cache_keys, $ck;
    }
    my $thread_read = {};
    if (@cache_keys > 1) {
        $thread_read = $battie->from_cache(@cache_keys);
    }
    else {
        my $read = $battie->from_cache(@cache_keys);
        $thread_read->{ $cache_keys[0] } = $read;
    }
#    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$thread_read], ['thread_read']);

    my @unfinished;
    for my $tid (@ids) {
        my $ck = "poard/read_thread/$uid/$tid";
        next if $thread_read->{ $ck };
        push @unfinished, $tid;

    }
    my @search;
    if (@unfinished) {
        @search = $schema->resultset('ReadMessages')->search({
            user_id => $uid,
            thread_id => { 'IN' => [@unfinished] },
        })->all;
    }
    my %id2pos;
    my %id2time;
    my %id2mtime_sub;
    while (my $read = shift @search) {
        my $tid = $read->thread_id;
        my $ck = "poard/read_thread/$uid/$tid";
        my $ro = $read->readonly;
        $ro->set_mtime(undef);
        $battie->to_cache($ck, $ro, 60 * 60 * 24 * 5);
        $thread_read->{ $ck } = $ro;
    }
    for my $key (keys %$thread_read) {
        my $read = $thread_read->{ $key } or next;
        my $tid = $read->thread_id;
        $id2pos{ $tid } = $read->position;
        $id2time{ $tid } = $read->mtime_epoch;
        if (my $meta = $read->meta) {
            for my $id (keys %$meta) {
                $id2mtime_sub{ $id } = $meta->{ $id };
            }
        }
    }
    for my $thread (@$list) {
        my $pos = $id2pos{$thread->id};
        my $time = $id2time{$thread->id};
        my $t = $thread->title;
        next unless defined $pos;
        if ($thread->is_tree) {
            my $l = 0;
            if ($thread->last) {
                my $last = $thread->last;
                my $lmtime = $last->mtime || $last->mtime_epoch || $last->ctime || $last->ctime_epoch;
                $lmtime = $lmtime->epoch if ($lmtime and ref $lmtime);
                $l = $lmtime if $lmtime;
#                $l = $thread->last ? ($thread->last->mtime->epoch || $thread->last->ctime->epoch): 0;
            }
            if (!$l or $time >= $l) {
                $thread->set_is_read(1);
                $thread->set_last_read($pos);
            }
            else {
                $thread->set_is_read(0);
                $thread->set_last_read($pos);
            }
            my $meta = $thread->meta || {};
            my %all_subtrees = %{ $meta->{subtrees} || {} };
            if (my $subtrees = $thread->subtrees) {
                for my $s (@$subtrees) {
                    my $rtime = delete $id2mtime_sub{ $s->{id} };
                    if ($rtime and $rtime >= $s->{mtime}) {
                        $s->{read} = 1;
                    }
                    delete $all_subtrees{ $s->{id} };
                }
                my ($root_id) = keys %all_subtrees;
                my $root_data = $all_subtrees{$root_id};
                if ($time >= $root_data->{mtime}) {
                    $thread->set_is_read(1);
                    $thread->set_last_read($pos);
                }
            }
        }
        else {
            my $l = $thread->last ? ($thread->last->position||0) : 0;
            #warn __PACKAGE__.':'.__LINE__.": last: $l\n";
            if ($pos >= $l) {
                $thread->set_is_read(1);
                $thread->set_last_read($pos);
            }
            else {
                $thread->set_is_read(0);
                $thread->set_last_read($pos);
            }
        }
    }
    return $thread_read;
}

sub poard__show_unapproved_messages {
    my ($self, $battie) = @_;
    my $onhold = $self->get_onhold($battie);
    $battie->get_data->{poard}->{onhold_messages} = $onhold;
}

sub get_onhold {
    my ($self, $battie) = @_;
    my $onhold = $battie->from_cache('poard/onhold');
    unless ($onhold) {
        $self->init_db($battie);
        my $schema = $self->schema->{poard};
        my $search = $schema->resultset('Message')->search({
                status => 'onhold',
            });
        my @msgs;
        while (my $message = $search->next) {
            my $ro = $message->readonly;
            $self->_times_for_cache($ro);
            if (my $author_id = $ro->author_id) {
                my $author = $battie->module_call(login => 'get_user_by_id', $author_id);
                $ro->set_author($author->readonly([qw/ id nick /]));
            }
            push @msgs, $ro;
        }
        $onhold = \@msgs;
        $battie->to_cache('poard/onhold', $onhold, 60 * 60 * 2);
    }
    else {
        $self->load_db($battie);
    }
    return $onhold;
}

sub approve_message {
    my ($self, $battie, $id) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $message = $schema->resultset('Message')->find($id);
    $self->exception("Argument", "Message '$id' does not exist") unless $message;
    my $thread = $message->thread;
    my $search = $schema->resultset('Message')->search(
        {
            id => $id,
            status => 'onhold',
        },
    );
    $self->write_message_log($battie, $schema, {
            msg_id          => $id,
            user_id         => $battie->get_session->userid,
            action          => 'approve_message',
        });
    my $updated = $search->update({
            status      => 'active',
            approved_by => $battie->get_session->userid,
            mtime       => DateTime->now,
            changelog   => 1,
        });
    if ($updated > 0) {
        $battie->delete_cache('poard/onhold');
        $thread->discard_changes;
        $self->delete_thread_cache($battie, $thread);
        $self->reset_thread_cache($battie, $thread);
        $message = $schema->resultset('Message')->find($id);
        $self->message_to_cache($battie, $message, 'set');
    }

    $self->update_search_index($battie, update => message => $message->id);
    $self->check_visibility($battie, $thread);
    $battie->writelog($message);
    if ($message->author_id) {
        $self->update_user_settings($battie, $message->author_id);
    }
    if ($message->position == 0 and $updated > 0) {
        $thread->status('active');
        $thread->approved_by($battie->get_session->userid);
        $thread->mtime(\'mtime');
        $thread->update;
        #$self->update_search_index($battie, update => thread => $thread->id);
    }
    return ($thread, $message);
}

sub poard__approve_message {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args = $request->get_args;
    my $submit = $request->get_submit;
    my $response = $battie->response;
    $response->set_no_cache(1);
    if ($submit->{approve} or $submit->{__default}) {
        unless ($battie->valid_token) {
            $battie->token_exception;
        }
        $self->exception("Argument", "Not enough arguments") unless @$args;
        my ($id) = @$args;
        my ($thread, $message) = $self->approve_message($battie, $id);
        if ($request->param('ajax')) {
            for ($thread, $message) {
                $_->discard_changes;
            }
            my $message_ro = $message->readonly;
            my $approver = $battie->module_call(login => 'get_user_by_id', $message->approved_by);
            if ($message->author_id) {
                $battie->module_call(login => 'approve_user', $message->author_id);
#                my $group_id = $user->group_id;
#                my $user_roles = $battie->module_call(login => 'get_roles_by_user', $message->author_id);
#                my $is_authorized = 0;
#                for my $urole (@$user_roles) {
#                    my $actions = $battie->module_call(login => 'get_actions_by_role_ids', $urole->role_id);
#                    $is_authorized = grep {
#                        $_ eq 'post_answer_authorized'
#                    } @$actions;
#                    last if $is_authorized;
#                }
#                unless ($is_authorized) {
#                    # user writes their first post, now approve them
#                    my $user_role = $battie->module_call(login => 'get_role_by_type', 'user');
#                    my $user = $battie->module_call(login => 'get_user_by_id', $message->author_id);
#                    $battie->module_call(login => 'add_role_to_user', $user, $user_role);
#                }
            }
            $message_ro->set_approved_by($approver->readonly) if $approver;
            if ($message_ro->is_deleted) {
                my $deletor = $battie->module_call(login => 'get_user_by_id', $message->lasteditor);
                $message_ro->set_lasteditor($deletor->readonly);
            }
            my $data = $battie->get_data;
            $data->{main_template} = "poard/ajax.html";
            $data->{poard}->{message} = $message_ro;
        }
        else {
            my $thread_id = $thread->id;
            $battie->set_local_redirect("/poard/thread/$thread_id");
            return;
        }
    }
}

sub poard__edit_thread_tags {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $self->init_db($battie);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    my $schema = $self->schema->{poard};
    my $thread = $schema->resultset('Thread')->find($id);
    $self->check_visibility($battie, $thread);
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    my $is_mod = $battie->allow->can_do(poard => 'mod_edit_thread');
    my $is_author = ($thread->author_id and $thread->author_id == $battie->get_session->userid);
    my $is_recent = $thread->ctime > DateTime->now->subtract( days => 1 );
    my $title = $request->param('thread.title');
    if ($submit->{save}) {
        $battie->require_token;
    }
    unless ($is_mod or ($is_author and $is_recent)) {
        if (!$is_author) {
            $battie->exception(Argument => "You are not the author");
        }
        else {
            $battie->exception(Argument => "The thread is older than one day. Please request the tags to be changed by a moderator");
        }
        $battie->exception(Argument => "Cannot edit");
    }
    my $thread_ro = $thread->readonly;
    my $board = $thread->board;
    my $tags = [];
    unless ($request->param('tags')) {
        $tags = [map { $_->readonly } $thread->tags ];
    }
    my ($tags_default, $tags_example, $tags_user) = $self->thread_default_tags($battie, $board);
    $data->{poard}->{tags_example} = $tags_example;
    $data->{poard}->{tags_default} = $tags_default;
    $data->{poard}->{tags_user} = $tags_user;
    my $plus = 3;
    my $result = $self->fetch_tags_from_form($battie, {
            tags => $tags,
            plus => $plus,
            prefix => ['tag', 'tag_new_user','tag_new_example'],
        });
    $data->{poard}->{use_tags} = $tags;
    if ($submit->{save} or $submit->{preview}) {
        if ($submit->{save}) {
            my @original_tags = $thread->tags;
            my %orig_names;
            @orig_names{ map { $_->name } @original_tags } = @original_tags;
            my @tag_ids;
            for my $tag (@$tags) {
                next unless length $tag->name;
                if (exists $orig_names{ $tag->name }) {
                    # already a thread tag
                    push @tag_ids, $orig_names{ $tag->name }->id;
                    delete $orig_names{ $tag->name };
                    next;
                }
                # new tag
                my $new_tag = $self->create_tag_for_thread($battie, $thread, $tag->name);
                push @tag_ids, $new_tag->id;
            }
            for my $name (keys %orig_names) {
                # tags to delete
                my $id = $orig_names{ $name }->id;
                $thread->delete_related('thread_tags', { tag_id => $id });
            }
            unless ($is_mod) {
                $thread->mtime(\'mtime');
                $thread->update;
            }
            my $uid = $battie->get_session->userid;
            if ($uid) {
                $self->update_user_tags($battie, \@tag_ids, $uid);
            }
            $battie->writelog($thread, "tags");
            $battie->set_local_redirect("/poard/thread/" . $thread->id);
            $thread->discard_changes;
            $self->reset_thread_cache($battie, $thread);
            return;
        }
    }
    $data->{poard}->{thread} = $thread_ro;
}

sub update_user_tags {
    my ($self, $battie, $tag_ids, $uid) = @_;
    return unless $uid;
    my $schema = $self->schema->{poard};
    my %ids;
    my @user_tags = $schema->resultset('UserTag')->search({
            user_id => $uid,
        }, {
            order_by => 'ctime desc',
        })->all;
    @ids{ map { $_->tag_id } @user_tags } = ();
    my @all_tags;
    my %seen;
    for my $tag_id (@$tag_ids) {
        push @all_tags, $tag_id;
        $seen{ $tag_id }++;
    }
    for my $user_tag (@user_tags) {
        next if $seen{ $user_tag->tag_id }++;
        push @all_tags, $user_tag->tag_id;
    }
    my $to_delete = -10 + @all_tags;
    for my $id (@all_tags) {
        if (exists $ids{ $id }) {
            delete $ids{ $id };
            next;
        }
        $schema->resultset('UserTag')->create({
                user_id => $uid,
                tag_id => $id,
            });
    }
    my @to_delete;
    @to_delete = splice @all_tags, 10 if $to_delete > 0;
    if (@to_delete) {
        my $test = $schema->resultset('UserTag')->search({
                tag_id => { IN => [@to_delete] },
                user_id => $uid,
            });
        my $count = $test->delete;
    }
}

sub create_tag_for_thread {
    my ($self, $battie, $thread, $name) = @_;
    my $schema = $self->schema->{poard};
    my $exists = $schema->resultset('Tag')->find({ name => $name });
    if ($exists) {
        $thread->add_to_tags($exists);
    }
    else {
        $exists = $thread->add_to_tags({
                name => $name,
            });
    }
    return $exists;
}

sub poard__edit_thread_title {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $self->init_db($battie);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    my $schema = $self->schema->{poard};
    my $thread = $schema->resultset('Thread')->find($id);
    $self->check_visibility($battie, $thread);
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    my $is_mod = $battie->allow->can_do(poard => 'mod_edit_thread');
    my $is_author = ($thread->author_id and $thread->author_id == $battie->get_session->userid);
    my $is_recent = $thread->ctime > DateTime->now->subtract( days => 1 );
    my $title = $request->param('thread.title');
    if ($submit->{save} or $submit->{__default}) {
        $battie->require_token;
        if (not defined $title or not length $title or $title !~ tr/ //c) {
            $data->{poard}->{error}->{no_title} = 1;
            delete $submit->{save};
            delete $submit->{__default};
        }
    }
    unless ($is_mod or ($is_author and $is_recent)) {
        if (!$is_author) {
            $battie->exception(Argument => "You are not the author");
        }
        else {
            $battie->exception(Argument => "The thread is older than one day. Please request the title to be changed by a moderator");
        }
        $battie->exception(Argument => "Cannot edit");
    }
    my $thread_ro = $thread->readonly;
    if ($submit->{save} or $submit->{__default}) {
        $thread_ro->set_title($title);
        if ($submit->{save} or $submit->{__default}) {
            $thread->title($title);
            $thread->mtime(\'mtime');
            $thread->update;
            $battie->writelog($thread, "title");
            $battie->set_local_redirect("/poard/thread/" . $thread->id);
            $self->update_search_index($battie, delete => thread => $thread->id);
            $self->update_search_index($battie, update => thread => $thread->id);
            $thread->discard_changes;
            $self->reset_thread_cache($battie, $thread);
            my $ck = "poard/thread_title/" . $thread->id;
            my $enc_title = encode_utf8($title);
            $battie->to_cache($ck, $enc_title, 60 * 60 * 24 * 30);
            return;
        }
    }
    $data->{poard}->{thread} = $thread_ro;
}

sub is_solvable {
    my ($self, $battie, $thread) = @_;
    my $can_solve = 0;
    my $is_mod = $battie->get_allow->can_do(poard => 'mod_solve_thread');
    if ($is_mod) {
        if (not $thread->status eq 'deleted') {
            $can_solve = 1;
        }
    }
    elsif ($battie->get_session->userid and $thread->author_id == $battie->get_session->userid) {
        if (not $thread->status eq 'deleted' and not $thread->closed) {
            $can_solve = 1;
        }
    }
    return $can_solve;
}

sub poard__solve_thread {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $response = $battie->response;
    $response->set_no_cache(1);
    $self->init_db($battie);
    my $args = $request->get_args;
    my ($id) = @$args;
    my $schema = $self->schema->{poard};
    my $thread = $schema->resultset('Thread')->find($id);
    $self->check_visibility($battie, $thread);
    my $can_solve = $self->is_solvable($battie, $thread);
    unless ($can_solve) {
        $self->exception("Argument", "Cannot solve/unsolve thread");
    }
    if ($submit->{solve} or $submit->{unsolve}) {
        $battie->require_token;
        if ($submit->{solve}) {
            $thread->update({
                    solved => 1,
                    mtime => \'mtime',
                });
            $battie->writelog($thread, "solve");
        }
        elsif ($submit->{unsolve}) {
            $thread->update({
                    solved => 0,
                    mtime => \'mtime',
                });
            $battie->writelog($thread, "unsolve");
        }
        $thread->discard_changes;
        $self->delete_thread_cache($battie, $thread);
        $self->reset_thread_cache($battie, $thread);
        $battie->set_local_redirect("/poard/thread/$id");
    }
}

sub poard__attachment {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $self->init_db($battie);
    my $args = $request->get_args;
    my $schema = $self->schema->{poard};
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($msid, $aid) = @$args;
    my $message = $schema->resultset('Message')->find($msid);
    $self->not_found_exception("Message '$msid' does not exist") unless $message;
    if ($message->status eq 'deleted') {
        $self->exception("Argument", "Message '$msid' is deleted");
    }
    my $thread = $message->thread;
    $self->check_visibility($battie, $thread);
    my $attachment = $schema->resultset('Attachment')->search({
            message_id  => $msid,
            attach_id   => $aid,
            deleted     => 0,
        })->single or $battie->not_found_exception("Attachment does not exist");
    my $filename = $attachment->filename;
    $battie->response->set_content_type($attachment->type);
    if ($attachment->type !~ m{^image/}) {
        $battie->response->get_header->{'Content-Disposition'}
            = "attachment; filename=${msid}_$filename";
    }
    $battie->response->get_header->{'X-Content-Type-Options'} = 'nosniff';
    my $data = $battie->get_data;
    $data->{main_template} = undef;

    my $conf = $self->get_attachment;
    my $attach_dir = $conf->{path};
    my $dirs = join '/', $msid =~ m/(\d{1,3})/g;
    my $file = "$attach_dir/$dirs/" . $attachment->attach_id;
    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$file], ['file']);
    open my $fh, '<', $file or die $!;
    my $content = do { local $/; <$fh> };
    $battie->response->set_output($content);
}

sub poard__edit_message {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $response = $battie->response;
    $response->set_no_cache(1);
    $self->init_db($battie);
    my $args = $request->get_args;
    my $schema = $self->schema->{poard};
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    my $message = $schema->resultset('Message')->find($id);
    $self->exception("Argument", "Message '$id' does not exist") unless $message;
    if ($message->status eq 'deleted') {
        $self->exception("Argument", "Message '$id' is deleted");
    }

    my $conf = $self->get_attachment;
    my $data = $battie->get_data;
    $data->{poard}->{attachment_conf} = $conf;
    my $thread = $message->thread;
    my $modedit = 0;
    my $ismod = 0;
    if ($battie->get_allow->can_do(poard => 'mod_edit_message')) {
        $ismod = 1;
    }
    elsif ($thread->closed) {
        $self->exception("Argument", "Thread is closed, no edits");
    }
    elsif (!$message->author_id or $message->author_id != $battie->get_session->userid) {
        $self->exception("Argument", "Message '$id' cannot be edited by you");
    }
    if (($message->author_id || 0) != $battie->get_session->userid) {
        $modedit = 1;
    }
    my $dont_update_mtime = $request->param('dont_update_mtime');

    $self->check_visibility($battie, $thread);
    my $from_form = $request->param('form');
    my $correct_bbcode = $request->param('correct_bbcode');
    my $correct_urls = $request->param('correct_urls');
    my $title = $request->param('message.title');
    my $edit_comment = $request->param('edit_comment');
    my $add_edit_comment = $request->param('add_edit_comment');
    if (defined $edit_comment) {
        $edit_comment =~ s/^\s+//;
        $edit_comment =~ s/\s+$//;
        unless (length $edit_comment) {
            undef $edit_comment;
        }
    }
    my $message_ro = $message->readonly;
    if (defined $title) {
        if (not length $title or $title !~ tr/ //c) {
            $title = undef;
        }
        $message_ro->set_title($title);
    }
    if ($submit->{save} or $submit->{attach}) {
        $battie->require_token;
    }
    my @attachments;
    my $thumb_dir = $conf->{thumbdir};
    my $dirs = join '/', $message->id =~ m/(\d{1,3})/g;
    $thumb_dir = $battie->get_paths->{docurl} . "/$thumb_dir";
    if ($message->has_attachment) {
        @attachments = $schema->resultset('Attachment')->search({
                message_id  => $message->id,
                $ismod ? () : (deleted     => 0),
            },
            {
                order_by => 'attach_id',
            })->all;
        my @ro;
        for my $attach (@attachments) {
            my $ro = $attach->readonly;
            if ($attach->thumb) {
                my $attach_id = $attach->attach_id;
                my (undef, $itype) = split m{/}, $attach->type;
                my $path = "$thumb_dir/$dirs/thumb_$attach_id.$itype";
                $ro->set_thumbnail_url($path);
            }
            push @ro, $ro;
        }
        $message_ro->set_attachments(\@ro);
    }
    if ($submit->{attach} and $battie->get_allow->can_do(poard => 'message_attach')) {
        my $total_size = 0;
        my $num_uploads = 0;
        my %names;
        for (@attachments) {
            $total_size += $_->size unless $_->deleted;
            $num_uploads++ unless $_->deleted;
            $names{ $_->filename }++ unless $_->deleted;
        }
        my ($attachments, $attachment_errors)
            = $self->fetch_attachments_from_form($battie, 2,
                {
                    num     => $num_uploads,
                    total_size  => $total_size,
                    filenames => \%names,
                });
        if (@$attachment_errors) {
            delete $submit->{attach};
            $submit->{preview} = 1;
            $data->{poard}->{error}->{attachment} = $attachment_errors;
        }
        my $redirect = 0;
        if (@$attachments) {
            my $max_attachment = $schema->resultset('Attachment')->search({
                    message_id  => $message->id,
                },
                {
                    order_by => 'attach_id desc',
                    rows => 1,
                    for => 'update',
                })->single;
            my $max_id = $max_attachment ? $max_attachment->attach_id : 0;
            $schema->txn_do(sub {
                    $self->add_attachments($battie, $message, $attachments, {
                            max_id => $max_id,
                        });
                    unless (@attachments) {
                        $message->update({ has_attachment => 1 });
                    }
                });
            if (my $e = $@) {
                warn __PACKAGE__.':'.__LINE__.": TRANSACTION FAILED: $@\n";
                $self->exception("SQL", "Could not edit message");
            }
            $redirect = 1;
        }
        my @to_delete = grep { m/^attach\.delete\.\d+\z/ } $request->param;
        my %attach = map { $_->attach_id => $_ } @attachments;
        for my $to_delete (@to_delete) {
            if ($request->param($to_delete)) {
                my ($aid) = $to_delete =~ m/^attach\.delete\.(\d+)\z/;
                my $attach = $attach{$aid};
                if ($attach->thumb) {
                    my (undef, $itype) = split m{/}, $attach->type;
                    my $path = "$thumb_dir/$dirs/thumb_$aid.$itype";
                    unlink $path;
                }
                $attach->update({ deleted => 1, thumb => 0 });
            }
            $redirect = 1;
        }
        if ($redirect) {
            $battie->set_local_redirect("/poard/edit_message/$id#attach");
        }
    }
    elsif ($submit->{save} or $submit->{preview}) {
        my $text = $request->param('message.message');
        my $result = $self->_check_message($battie, $text, {
                links => $correct_urls,
                bbcode => $correct_bbcode,
            });
        my $error = $result->{error};
        if (@$error and $ismod) {
            @$error = grep { $_ ne "too_long" } @$error;
        }
        if (@$error) {
            $text = $result->{text};
            for my $e (@$error) {
                $data->{poard}->{error}->{message}->{$e} = 1;
            }
        }
        if (@$error and $submit->{save}) {
            $submit->{preview} = delete $submit->{save};
        }
        if ($submit->{preview}) {
            $message_ro->set_message($text) if defined $text;
        }
        elsif ($submit->{save}) {
            $text = $result->{text};
            my $redir = '';
            my $thread_id = $thread->id;
            eval {
                $schema->txn_do(sub {
                        if ($text ne $message->message) {
                            my $archived = $schema->resultset('ArchivedMessage')->create({
                                    msg_id      => $message->id,
                                    message     => $message->message,
                                    thread_id   => $message->thread_id,
                                    ctime       => ($message->mtime || $message->ctime),
                                    lasteditor_id   => $message->lasteditor || $message->author_id,
                                });
                        }
                        if (defined $edit_comment and $add_edit_comment) {
                            my $translation = $battie->translation;
                            my $edited_by = $translation->translate("poard_edited_by");
                            $edited_by = "[b]modedit[/b] $edited_by" if $modedit;
                            $text .= "\n\n[i]$edited_by [user]"
                                . $battie->get_session->userid
                                . "[/user]: $edit_comment\[/i]";
                        }
                        $message->message($text);
                        $message->title($title);
                        $message->lasteditor($battie->get_session->userid);
                        $message->changelog(1);
                        $message->update;

                        $self->write_message_log($battie, $schema, {
                                msg_id          => $message->id,
                                user_id         => $battie->get_session->userid,
                                edit_comment    => $edit_comment,
                                action          => 'edit_message',
                            });

                        $self->update_subtrees($battie, $thread);
                        unless ($dont_update_mtime) {
                            $thread->mtime(DateTime->now);
                            $thread->update;
                            $thread->discard_changes;
                        }

                        $self->message_to_cache($battie, $message, 'set');

                        $battie->writelog($message);
                        $self->delete_thread_cache($battie, $thread);
                        $self->reset_thread_cache($battie, $thread);
                        if ($thread->is_tree) {
                            my $subtrees = ($thread->meta || {})->{subtrees};
                            my $previous = $self->parents_to_msg($battie, $schema, $id);
                            for my $p (@$previous) {
                                my $id = $p->id;
                                if ($subtrees->{ $id }) {
                                    $redir = "/$id";
                                    last;
                                }
                            }
                        }
                    });
            };
            if (my $e = $@) {
                warn __PACKAGE__.':'.__LINE__.": TRANSACTION FAILED: $@\n";
                $self->exception("SQL", "Could not edit message");
            }
            else {
                $self->update_search_index($battie, update => message => $id);
                $battie->set_local_redirect("/poard/thread/$thread_id$redir#ms_$id");
            }
        }
    }
    my $re = $battie->get_render->render_message_html($message_ro->message, $message_ro->id);
    $message_ro->set_rendered($re);
    $data->{poard}->{correct_bbcode} = $from_form ? $correct_bbcode : 1;
    $data->{poard}->{correct_urls} = $from_form ? $correct_urls : 1;
    $data->{poard}->{message} = $message_ro;
    $data->{poard}->{edit_comment} = $edit_comment;
    $data->{poard}->{add_edit_comment} = $add_edit_comment ? 1 : 0;
    $data->{poard}->{thread} = $thread->readonly;
    $data->{subtitle} = "Board - Edit Article";
}

sub _check_message {
    my ($self, $battie, $text, $args) = @_;
    $text = '' unless defined $text;
    my $server = $battie->get_paths->{server};
    $server =~ s{^https?://}{};
    my $prefix = $battie->get_paths->{view};
    my %result = ( error => [] );
    $text =~ s/^\s*(.*?)\s*\z/$1/s;
    $result{text} = $text;
    my $l = length $text;
    if ($l > 30_000) {
        push @{ $result{error} }, 'too_long';
    }
    else {
        my $tree =  $battie->get_render->parse_message($text);
        my $new_length = $l;
        my $found = 0;
        my $more_tags = 1;
        my $render = $battie->get_render;
        while ($new_length > 10_000) {
            my $count = 0;
            my $tag = $render->find_tag($tree, more => $found, \$count);
            unless ($tag) {
                $more_tags = 0;
                last;
            }
            my $raw = $tag->raw_text;
            $new_length -= length $raw;
            $found++;
        }
        unless ($more_tags) {
            push @{ $result{error} }, 'too_long2';
            return \%result;
        }
        my $parser = $render->get_bbc2html;
        if ($args->{bbcode}) {
            $parser->set_close_open_tags(1);
            my $tree =  $battie->get_render->parse_message($text);
            my $error = $parser->error;
            if ($error) {
                my $raw = $tree->raw_text;
                $result{text} = $raw;
                push @{ $result{error} }, 'bbcode';
            }
        }
        if ($args->{links}) {
            my $tree =  $battie->get_render->parse_message($result{text});
            my $correct = 0;
            my $finder = URI::Find->new(sub {
                    my ($uri, $text) = @_;
                    if (ref ($uri) ne 'URI::mailto' and $uri->host eq $server) {
                        $correct = 1;
                        my $url = $uri->full_path;
                        if ($url =~ m{$prefix/poard/thread/(\d+)$}) {
                            return "[thread]$1\[/thread]";
                        }
                        elsif ($url =~ m{$prefix/poard/message/(\d+)$}) {
                            return "[msg]$1\[/msg]";
                        }
                        elsif ($url =~ m{$prefix/poard/board/(\d+)$}) {
                            return "[board]$1\[/board]";
                        }
                        $url .= '#' . $uri->fragment if length($uri->fragment);
                        return "[url]$url\[/url]";
                    }
                });
            $render->find_text($parser, $tree, sub {
                    my ($text) = @_;
                    $finder->find($text);
                });
            if ($correct) {
                my $raw = $tree->raw_text;
                $result{text} = $raw;
                push @{ $result{error} }, 'url';
            }
        }
        $parser->set_close_open_tags(0);
    }
    return \%result;
}

sub write_message_log {
    my ($self, $battie, $schema, $param) = @_;
    my $message_id = $param->{msg_id};
    my $user_id = $battie->get_session->userid;
    my $edit_comment = $param->{edit_comment};
    my $action = $param->{action};
    my $logs = $schema->resultset('MessageLog')->search({
            message_id  => $message_id,
        },
        {
            rows => 1,
            order_by => 'log_id desc',
            for => 'update',
        })->single;
    my $log_id = 1;
    if ($logs) {
        $log_id = $logs->log_id + 1;
    }

    my $log = $schema->resultset('MessageLog')->create({
            message_id  => $message_id,
            log_id      => $log_id,
            user_id     => $user_id,
            action      => $action,
            comment     => $edit_comment,
        });
}

sub poard__mod_move_thread {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    my $response = $battie->response;
    $response->set_no_cache(1);
    $self->exception("Argument", "Not enough arguments") unless @$args > 0;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $thread = $self->check_existance($battie, Thread => $id);
    my $data = $battie->get_data;
    # TODO $battie->valid_token
    if ($submit->{move}) {
        my $movefrom = $request->param('movefrom') || 0;
        if ($movefrom != $thread->board_id) {
            $self->exception('Race', 'This thread is not in this board any more.');
        }
        my $info = $request->param('info') || '';
        $info =~ s/\s+$//g;
        my $no_info = $request->param('no_info') || 0;
        if ($no_info) {
            $info = '';
        }
        my $moveto = $request->param('moveto');
        $self->check_visibility($battie, $thread);
        unless (defined $moveto && length $moveto) {
            $self->exception('Argument', 'No target board specified')
        }
        my $board = $schema->resultset('Board')->find($moveto);
        $self->exception('Argument', "Board '$moveto' does not exist.") unless $board;
        # TODO
        #$self->check_visibility($battie, $thread);
        $battie->not_found_exception("Board '$moveto' is not visible by you", [])
            unless $self->check_board_group($battie, $board);
        $self->exception('Argument', "Board '$moveto' is a superboard.") if $board->lft == 1;
        $self->exception("Argument", "Board '$moveto' is a superboard.") unless $board->is_leaf;
        $info =~ s#\[board\]MOVE_TO\[/board\]#[board]$moveto\[/board]#x;
        {
            $schema->txn_begin;
            my $message;
            eval {
                my $parent = $thread->search_related('messages', undef, {
                    order_by => 'position desc',
                    rows => 1,
                    'for' => 'update',
                })->single;
                my $max_pos = $parent->position;
                my $parent_id = $parent->id;
                if ($thread->is_tree) {
                    my $parent = $thread->search_related('messages', undef, {
                        order_by => 'lft asc',
                        rows => 1,
                        'for' => 'update',
                    })->single;
                    $parent_id = $parent->id;
                }
                if (length $info) {
                    $message = $schema->resultset('Message')->insert_new($parent_id, {
                        author_id => $battie->get_session->userid || 0,
                        message => $info,
                        status => 'active',
                        thread => $thread,
                        ctime => undef,
                        position => 1 + $max_pos,
                    });
                    $self->update_search_index($battie, update => message => $message->id);
                    $self->update_thread_count($thread);
                    $data->{poard}->{message} = $message->readonly;
                }
                else {
                    $thread->mtime(\'mtime');
                }
                $thread->board($board);
                $thread->update;
                $thread->discard_changes;
                $self->delete_thread_cache($battie, $thread);
                $self->reset_thread_cache($battie, $thread);
            };
            if (my $e = $@) {
                $schema->txn_rollback;
                $self->exception("SQL", "Could not move thread: $e");
            }
            else {
                $schema->txn_commit;
            }
        }
        # TODO
        $thread->discard_changes;
        $self->delete_thread_cache($battie, $thread);
        $self->reset_thread_cache($battie, $thread);
        $self->update_search_index($battie, update => thread => $thread->id);
        $battie->set_local_redirect("/poard/thread/".$thread->id);
        $battie->writelog($thread);
        return;
    }
    my $tree = $self->create_board_tree($battie, undef, "</optgroup>");
    $data->{poard}->{board_tree} = $tree;
    my $thread_ro = $thread->readonly;
    $thread_ro->set_board($thread->board->readonly);
    $data->{poard}->{thread} = $thread_ro;
    $data->{subtitle} = "Board - Move Thread";
}

sub poard__mod_merge_thread {
    my ($self, $battie) = @_;
    # TODO
    return;
}

sub poard__mod_reparent {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $args = $request->get_args;
    $self->init_db($battie);
    $self->exception("Argument", "Not enough arguments") unless @$args > 1;
    my ($tid, $mid) = @$args;
    $self->init_db($battie);

    my $thread = $self->check_existance($battie, Thread => $tid);
    $self->exception("Argument", "Thread is not a tree") unless $thread->is_tree;
    my $msg = $self->check_existance($battie, Message => $mid);
    $self->check_visibility($battie, $thread);
    $self->check_msg_in_thread($thread, $msg);
    $self->exception("Argument", "Message '$mid' is already first message")
        if (!$msg->position or $msg->lft == 1);
    if ($submit->{reparent} and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{reparent}) {
    }
    my $data = $battie->get_data;
    my $msg_list = $self->create_msg_tree($thread, 'small');
    for my $item (@$msg_list) {
        if ($item->lft >= $msg->lft and $item->rgt <= $msg->rgt) {
            $item->set_is_selectable(0);
        }
        else {
            $item->set_is_selectable(1);
        }
    }
    $data->{poard}->{thread} = $thread->readonly;
    $data->{poard}->{msg} = $msg->readonly;
    $data->{poard}->{msgs} = $msg_list;
}

sub create_msg_tree {
    my ($self, $thread) = @_;
    return unless $thread->is_tree;

    my @msgs = $thread->search_related('messages', {},
    { order_by => 'lft asc' },
    );
    my $RGT;
    my @l;
    my $last_level = 1;
    my $rendered_messages = [];
    for my $msg (@msgs) {
        my $last = 1;
        my ($id, $lft, $rgt) = ($msg->id, $msg->lft, $msg->rgt);
        my $ro = $msg->readonly;
        #$self->set_message_edit_status($battie, $ro);

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

        if (@$rendered_messages and @l < $last_level) {
            $ro->set_level_down([(1) x ($last_level - @l)]);
        }
        $last_level = @l;
        $ro->set_is_last($last);
        push @$rendered_messages, $ro;
        $RGT = $rgt;
    }
    return $rendered_messages;
}

sub check_visibility {
    my ($self, $battie, $thread) = @_;
    my $id = $thread->id;
    $battie->not_found_exception("Thread '$id' is not visible by you", [])
        unless $self->check_board_group($battie, $thread->board);
}

sub check_msg_in_thread {
    my ($self, $thread, $msg) = @_;
    my $mid = $msg->id;
    my $tid = $thread->id;
    $self->exception("Argument", "Message '$mid' is not in thread '$tid'")
        unless $msg->thread_id == $tid;
}

sub check_existance {
    my ($self, $battie, $type, $id, $args) = @_;
    $args ||= {};
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $object = $schema->resultset($type)->find($id, $args)
        or $battie->not_found_exception("$type '$id' does not exist");
    return $object;
}

sub poard__mod_split_thread {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args > 1;
    my ($id, $msid) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $thread = $self->check_existance($battie, Thread => $id);
    my $msg = $schema->resultset('Message')->find($msid);
    $self->exception("Argument", "Message '$msid' does not exist") unless $msg;
    $self->exception("Argument", "Message '$msid' is not in thread '$id'") unless $msg->thread_id == $id;
    $self->exception("Argument", "Message '$msid' is already root") if $msg->is_root;
    $self->exception("Argument", "Thread '$id' is not a tree") unless $thread->is_tree;
    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$submit], ['submit']);
    if ($submit->{really_split} and not $battie->valid_token) {
        $battie->token_exception;
    }
    my $title = $request->param('thread.title');
    my $msg_title = $msg->title;
    my $new_title = $title || $msg_title || $thread->title . " split";
    if ($submit->{really_split}) {
        my $target = $request->param('target');
        my $target_board;
        if ($target) {
            $target_board = $schema->resultset('Board')->find($target);
            $self->exception('Argument', "Board '$target' does not exist.") unless $target_board;
            $battie->not_found_exception("Board '$target' is not visible by you", [])
                unless $self->check_board_group($battie, $target_board);
        }
        my $redir;
        eval {
            $schema->txn_do(sub {
                    my $rgt = $msg->rgt;
                    my $lft = $msg->lft;
                    my $add_info = $request->param('add_info_message');
                    my @parents = $schema->resultset('Message')->parents($msg)->all;
                    my $parent_message = pop @parents;
                    my $count = ($rgt - $lft + 1);
                    my $msgs = $count / 2;
                    my $new_thread = $schema->resultset('Thread')->create(
                        {
                            title       => $new_title,
                            status      => 'active',
                            board_id    => ($target_board ? $target_board->id : $thread->board_id),
                            is_tree     => 1,
                            author_id   => $msg->author_id,
                            author_name => $msg->author_name,
                            messagecount => $msgs - 1,
                        }
                    );
                    if ($add_info) {
                        $msgs--;
                    }
                    $thread->update({
                            messagecount => \"messagecount - $msgs",
                        });

                    my $children = $schema->resultset('Message')->search({
                            thread_id => $id,
                            lft => { '>=', $lft },
                            rgt => { '<=', $rgt },
                        }, { for => 'update' });

                    my $minus = $lft - 1;
                    my $new_tid = $new_thread->id;
                    $children->update({
                            thread_id => $new_tid,
                            lft       => \"lft - $minus",
                            rgt       => \"rgt - $minus",
                        });


                    my $before = $schema->resultset('Message')->search({
                            thread_id => $id,
                            lft => { '<', $lft },
                            rgt => { '>', $rgt },
                        }, { for => 'update' });
                    $before->update({
                            rgt => \"rgt - $count",
                        });

                    my $after = $schema->resultset('Message')->search({
                            thread_id => $id,
                            lft => { '>', $rgt },
                        }, { for => 'update' });
                    $after->update({
                            rgt => \"rgt - $count",
                            lft => \"lft - $count",
                        });

                    my $search = $schema->resultset('ReadMessages')->search({
                            thread_id => $thread->id,
                        });
#                    my $rs = $schema->resultset('ReadMessagesView')->search({},
#                        {
#                            bind => [$new_thread->id, $thread->id],
#                        })->all;
#                    warn __PACKAGE__.':'.__LINE__.": $rs\n";
#                    die "rollback";
                    my @new_read;
                    while (my $read = $search->next) {
                        push @new_read, {
                            thread_id   => $new_thread->id,
                            user_id     => $read->user_id,
                            position    => $read->position,
                            mtime       => $read->mtime . "",
                        };
                        if (@new_read >= 50) {
                            $schema->resultset('ReadMessages')->populate([@new_read]);
                            @new_read = ();
                        }
                    }
                    $schema->resultset('ReadMessages')->populate([@new_read]) if @new_read;

                    my $new_text = $msg->message . <<EOM;


[i]Splitted from [thread]@{[ $thread->id ]}\[/thread] [msg]@{[ $parent_message->id ]}\[/msg][/i]
EOM

                    my $orig_text = $msg->message;
                    my %update_msg = (
                        message => $new_text,
                    );
                    if (defined $msg_title) {
                        $update_msg{title} = undef;
                    }
                    $msg->update(\%update_msg);
                    if ($add_info) {
                        my $author_id = $msg->author_id;
                        my $author;
                        if ($author_id) {
                            $author = $battie->module_call(login => 'get_user_by_id', $author_id);
                        }
                        if (length($orig_text) > 50) {
                            substr($orig_text, 50) = '...';
                        }
                        my $info = <<"EOM";
Splitted to [thread]$new_tid\[/thread]

Original message by '@{[ $author ? $author->nick : $msg->author_name ]}':
[quote]$orig_text\[/quote]
EOM
                        my $new_message = $schema->resultset('Message')->insert_new($parent_message->id,
                            {
                                author_id => $battie->get_session->userid,
                                message   => $info,
                                status    => 'active',
                                thread_id => $id,
                                position  => $msg->position,
                            }
                        );
                    }
                    $redir = $new_tid;
                    $self->update_subtrees($battie, $thread);
                    $thread->update;
                    $self->update_subtrees($battie, $new_thread);
                    $new_thread->update;
            });
        };
        if ($@) {
            warn __PACKAGE__.':'.__LINE__.": ERROR: $@\n";
        }
        # TODO no board if board changed
        $thread->discard_changes;
        $self->delete_thread_cache($battie, $thread);
        $self->reset_thread_cache($battie, $thread);

        $battie->set_local_redirect("/poard/thread/$redir");
        #$schema->txn_rollback;
    }
    my $data = $battie->get_data;
    $data->{poard}->{new_title} = $new_title;
    $data->{poard}->{thread} = $thread->readonly;
    $data->{poard}->{message} = $msg->readonly;
    my $tree = $self->create_board_tree($battie, undef, "</optgroup>");
    $data->{poard}->{board_tree} = $tree;
}

sub poard__mod_split_thread2 {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args > 1;
    my ($id, $msid) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $thread = $self->check_existance($battie, Thread => $id);
    my $msg = $schema->resultset('Message')->find($msid);
    $self->exception("Argument", "Message '$msid' does not exist") unless $msg;
    $self->exception("Argument", "Message '$msid' is not in thread '$id'") unless $msg->thread_id == $id;
    my $pos = $msg->position;
    $self->check_visibility($battie, $thread);
    $self->exception("Argument", "Message '$msid' is already first message") unless $pos;
    my $data = $battie->get_data;
    my $message_ro = $msg->readonly;
    my $thread_ro = $thread->readonly;
    my $info = $request->param('new_thread.text') || '';
    my $new_title = $request->param('new_thread.title') || '';
    if ($submit->{split} and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{split} and $info and $new_title) {
        # i think we need transactions here
        $schema->txn_begin;
        my $new_id;
        my $new_thread;
        eval {
            $new_thread = $schema->resultset('Thread')->create(
                {
                    title => $new_title,
                    status => 'onhold',
                    board_id => $thread->board_id,
                    ctime => undef,
                    is_tree => $thread->is_tree,
                }
            );
            my $new_pos = 0;
            {
                my $s = $schema->resultset('Message')->search(
                    {
                        thread_id => $id,
                    },
                    {
                        order_by => 'position desc',
                        rows => 1,
                    },
                );
                my $row = $s->next;
                $new_pos = $row->position + 1;
            }
            my $search = $schema->resultset('Message')->search(
                {
                    thread_id => $id,
                    position => { '>=' => $pos },
                },
            );
            $info =~ s# \[thread\]SPLIT_TO\[/thread\] #[thread]$new_id\[/thread]#x;
            $info = '[small][user]' . $battie->get_session->userid . '[/user]: ' . $info . '[/small]';
            my $parent;
            if (my $first = $search->next) {
                $parent = $first;
                my $text = $first->message;
                $text = $info . "\n" . $text;
                $first->message($text);
                $first->position(0);
                $first->thread_id($new_id);
                $first->update;
            }
            $search->update(
                {
                    mtime => \'mtime',
                    thread_id => $new_id,
                }
            );
            my $new_message = $schema->resultset('Message')->insert_new($parent->id,
                {
                    author_id => $battie->get_session->userid || 0,
                    message => $info,
                    status => 'active',
                    thread_id => $id,
                    ctime => undef,
                    position => $new_pos,
                }
            );
            $new_thread->status($thread->status);
            $new_thread->author_id($msg->author_id);
            $new_thread->author_name($msg->author_name);
            $new_thread->update;
            $self->update_thread_count($new_thread);
            $self->update_thread_count($thread);
            $self->update_search_index($battie, update => message => $new_message->id);
        };
        if ($@) {
            $schema->txn_rollback;
            $self->exception("SQL", "Could not split thread");
        }
        else {
            $schema->txn_commit;
            $self->expire_cache($battie, $thread);
            $self->expire_cache($battie, $new_thread);
            $battie->set_local_redirect("/poard/thread/$new_id");
            $battie->writelog($thread);
        }
        return;
    }
    $data->{poard}->{message} = $message_ro;
    $data->{poard}->{thread} = $thread_ro;
    $data->{subtitle} = "Board - Split Thread";
}

sub update_thread_count {
    my ($self, $thread) = @_;
    my $schema = $self->schema->{poard};
    my $count = $schema->resultset('Message')->count(
        {
            thread_id => $thread->id,
            status => 'active',
        }
    );
    $thread->messagecount($count-1);
    $thread->update;
}

sub poard__post_answer {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $submit = $request->get_submit;
    $self->init_db($battie);
    my $args = $request->get_args;
    my $schema = $self->schema->{poard};
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id, $msid) = @$args;
    my $thread = $self->check_existance($battie, Thread => $id);
    $self->exception("Argument", "Thread '$id' is not yet approved") unless $thread->status eq 'active';
    my $board = $self->fetch_boards($battie, $thread->board_id);
    my $thread_ro = $thread->readonly;
    $thread_ro->set_board($board);
    $self->check_visibility($battie, $thread_ro);
    my $data = $battie->get_data;
    if ($self->get_post_hint) {
        $data->{poard}->{post_hint} = 1;
    }
    my $from_form = $request->param('form');
    my $correct_bbcode = $request->param('correct_bbcode');
    my $correct_urls = $request->param('correct_urls');
    if ($request->param('confirmation')) {
        $data->{poard}->{confirmation} = 1;
        $data->{poard}->{msg_id} = $request->param('msg_id');
        $data->{poard}->{thread_id} = $id;
        $data->{poard}->{subtree} = $msid;
        return;
    }
    if ($submit->{attach}) {
        $submit->{preview} = delete $submit->{attach};
    }
    my $quote = 0;
    my $title = $request->param('message.title');
    if ($submit->{preview_new_title}) {
        $data->{poard}->{new_title} = '';
        $submit->{preview} = delete $submit->{preview_new_title};
    }
    if (defined $title) {
        $data->{poard}->{new_title} = $title;
        if (not length $title or $title !~ tr/ //c) {
            $title = undef;
            $data->{poard}->{new_title} = $title;
        }
    }
    unless ($thread->is_tree) {
        $data->{poard}->{new_title} = $title = undef;
    }
    if ($submit->{preview_quote}) {
        $quote = 1;
        $submit->{preview} = delete $submit->{preview_quote};
    }
    my $orig_message;
    if ($msid) {
        $orig_message = $schema->resultset('Message')->find($msid)
            or $self->exception(Argument => "Message you are replying to does not exist anymmore");
        if ($orig_message->thread_id != $id) {
            $submit->{preview} = delete $submit->{post} || 1;
            $data->{poard}->{error}->{message_in_different_thread} = $orig_message->thread_id;
        }
    }
    elsif ($thread->is_tree) {
        $self->exception(Argument => "No message to reply");
    }
    if ($orig_message and $orig_message->status ne 'active') {
        $self->exception(Argument => "Message '$msid' does not exist or is deleted");
    }
    if ($thread->closed and not $battie->get_allow->can_do(poard => 'mod_close_thread')) {
        # only people who can close/open threads can post in closed threads
        $self->exception("Argument", "Thread '$id' is closed");
    }
    my $can_post = $battie->get_allow->can_do(poard => 'post_answer_authorized');
    my $author_name = $request->param('message.author_name');
    if ($submit->{post} and !$battie->valid_token) {
        delete $submit->{post};
        $submit->{preview} = 1;
        $data->{poard}->{error}->{token} = 1;
    }
    if (!$can_post and not $battie->get_session->userid and (not defined $author_name or not length $author_name or $author_name =~ m/^\s*\z/)) {
        # we have a guest, so we need a name
        delete $submit->{post};
        $submit->{preview} = 1;
        $data->{poard}->{error}->{name_required} = 1;
    }
    elsif (!$can_post) {
        # first check how many unapproved messages we have in the thread
        my $max = $self->get_max_unapproved || 0;
        if ($max) {
            my $count = $schema->resultset('Message')->count(
                {
                    thread_id => $id,
                    status => 'onhold',
                }
            );
            if ($count >= $max) {
                $self->exception("Argument", "Already $max unapproved messages in thread '$id', please try later");
            }
        }
    }
    elsif ($submit->{post}) {
        # a user should wait a number of seconds between postings
        my $sec = $self->get_post_delay;
        $sec =~ tr/0-9//cd;
        $sec ||= 1;
        my $minus = DateTime->now->subtract(seconds => $sec);
        my $count = $schema->resultset('Message')->count(
            {
                author_id => $battie->get_session->userid,
                mtime => { '>=', $minus },
            },
        );
        if ($count) {
            delete $submit->{post};
            $submit->{preview} = 1;
            $data->{poard}->{error}->{post_delay} = 1;
        }
    }
    my $text = $request->param('message.message');
    $text = '' unless defined $text;
    if (not keys %$submit or $submit->{preview} or $submit->{post}) {
        my $result = $self->_check_message($battie, $text, {
                links => $correct_urls,
                bbcode => $correct_bbcode,
            });
        my $error = $result->{error};
        if (@$error) {
            $text = $result->{text};
            for my $e (@$error) {
                $data->{poard}->{error}->{message}->{$e} = 1;
            }
        }
        if (@$error and $submit->{post}) {
            $submit->{preview} = delete $submit->{post};
        }
        if ($submit->{post}) {
            $text = $result->{text};
        }
    }


    if ($submit->{post}) {
        if ($text =~ m/^\s*\z/) {
            delete $submit->{post};
            $submit->{preview} = 1;
        }
        if ($self->get_antispam and not $request->param('antispam_ok')) {
            delete $submit->{post};
            $submit->{preview} = 1;
        }
        unless ($can_post) {
            # guest or new user
            my $is_spam = $battie->spamcheck(
                $self->get_antispam,
                text => $text,
                defined $author_name ? (author => $author_name) : (),
            );
            if ($is_spam) {
                $battie->log_spam(
                    text => $text,
                    type => "message",
                );
                delete $submit->{post};
                $submit->{preview} = 1;
                $data->{poard}->{error}->{spam} = 1;
            }
        }
    }
    my $conf = $self->get_attachment;
    $data->{poard}->{attachment_conf} = $conf;
    my $attachments = [];
    my $attachment_errors = [];
    $data->{poard}->{antispam} = $self->get_antispam;
    if ($submit->{preview} or $submit->{post}) {
        my $save = 0;
        if ($submit->{post}) {
            $save = 1;
        }
        if ($battie->get_allow->can_do(poard => 'message_attach')) {
            ($attachments, $attachment_errors)
                = $self->fetch_attachments_from_form($battie, $save);
            $data->{poard}->{attachments} = $attachments;
            if (@$attachment_errors) {
                delete $submit->{save};
                $submit->{preview} = 1;
                $data->{poard}->{error}->{attachment} = $attachment_errors;
            }
        }
    }


    if (not keys %$submit or $submit->{preview}) {
        if ($thread->is_tree) {
            my $last_lft = $request->param('lft');
            my $last_rgt = $request->param('rgt');
            $data->{poard}->{last_lft} = $orig_message->lft;
            $data->{poard}->{last_rgt} = $orig_message->rgt;
            if ($last_lft and $last_rgt) {
                my $last_count = $last_rgt - $last_lft;
                my $count = $orig_message->rgt - $orig_message->lft;
                if ($count > $last_count) {
                    # new messages since clicked reply
                    $data->{poard}->{hint}->{new_answers} = 1;
                }
            }
        }
        $response->set_no_cache(0); # otherwise textarea will be emptied
        my $quoted_text = '';
        if ($quote) {
            my $message = $schema->resultset('Message')->find($msid);
            if ($message->status eq 'deleted') {
                $self->exception("Argument", "Message '$msid' is deleted");
            }
            elsif ($message->status eq 'onhold') {
                $self->exception("Argument", "Message '$msid' is not yet approved");
            }
            my $qthread = $message->thread;
            $self->check_visibility($battie, $qthread);
            if ($message) {
                my $ro = $message->readonly;
                if ($message->author_id) {
                    my $user = $battie->module_call(login => 'get_user_by_id', $message->author_id);
                    $ro->set_author($user->readonly);
		    # Hm, no idea how to handle user names that have stuff like ][ in them.
            # use [quote=userid@ctime]?
                    $quoted_text = '[quote="' . $user->nick. '@' . $message->ctime . '"]'
			. $message->message . "[/quote]\n";
                }
                else {
                    $ro->set_author_name($message->author_name);
                    $quoted_text = '[quote="Guest ' . $message->author_name. '"]' . $message->message . "[/quote]\n";
                }
                $data->{poard}->{quoted_message} = $ro;
            }
        }
        my $message_ro = WWW::Poard::Model::Message::Readonly->new({
                message => $quoted_text.$text,
                $can_post ? () : (author_name => $author_name),
            });
        my $re = $battie->get_render->render_message_html($message_ro->message);
        $message_ro->set_rendered($re);
        $data->{poard}->{thread} = $thread_ro;
        $data->{poard}->{message} = $message_ro;
        $data->{poard}->{msid} = $msid;
        $data->{subtitle} = "Board - Post Answer";
    }
    elsif ($submit->{post}) {
#        my $text = $request->param('message.message');
#        $text =~ s/^\s*(.*?)\s*\z/$1/s;
        $schema->txn_begin;
        my $message;
        my $mscount;
        my $thread_id;
        eval {
            my $search = $schema->resultset('Message')->search({
                    thread_id => $thread->id,
                },
                {
                    order_by => 'position desc',
                    rows => 1,
                }
            );
            my $pos = 0;
            my $parent_id = 0;
            if (my $post = $search->next) {
                $parent_id ||= $post->id;
                $pos = $post->position;
            }
            my %user_args = (
                author_id => $battie->get_session->userid,
            );
            unless ($battie->get_session->userid) {
                %user_args = (
                    author_name => $author_name,
                );
            }
            $message = $schema->resultset('Message')->insert_new($msid || $parent_id, {
                    message     => $text,
                    thread_id   => $thread->id,
                    ctime       => undef,
                    position    => $pos + 1,
                    title       => $title,
                    status      => $can_post ? 'active' : 'onhold',
                    (scalar @$attachments) ? (has_attachment => 1) : (),
                    %user_args,
                });
            $thread_id = $thread->id;

            # attachments
            if (@$attachments) {
                $self->add_attachments($battie, $message, $attachments);
            }

            # this should be in a transaction, but do we really care?
            $mscount = $schema->resultset('Message')->count({
                    thread_id => $thread->id,
                    status => { '!=' => 'deleted' },
                    });
            $thread->messagecount($mscount - 1);
            $self->update_subtrees($battie, $thread);
            $thread->update;
            $self->update_user_settings($battie, $battie->get_session->userid);
            if ($can_post) {
                $self->update_search_index($battie, update => message => $message->id);
            }

            $self->message_to_cache($battie, $message, 'set');
        };
        if (my $e = $@) {
            $schema->txn_rollback;
            warn __PACKAGE__.':'.__LINE__.": TRANSACTION FAILED: $e\n";
            $self->exception("SQL", "Could not create message");
        }
        else {
            $schema->txn_commit;
            unless ($can_post) {
                $battie->delete_cache('poard/onhold');
            }
            #warn __PACKAGE__.':'.__LINE__.": <<< $thread >>>\n";
            $self->expire_cache($battie, $thread);
            my $msid = $message->id;
            $battie->writelog($message);
            $battie->module_call(cache => 'delete_cache', "poard/thread/$id");
            my $page;
            if ($mscount % $rows_in_thread) {
                $page = ($mscount - ($mscount % $rows_in_thread)) / $rows_in_thread + 1;
            }
            else {
                $page = $mscount / $rows_in_thread;
            }
            $thread->discard_changes;
            $self->delete_thread_cache($battie, $thread);
            $self->reset_thread_cache($battie, $thread);
            my $redir = '';
            if ($thread->is_tree) {
                my $subtrees = ($thread->meta || {})->{subtrees};
                my $previous = $self->parents_to_msg($battie, $schema, $msid);
                pop @$previous;
                for my $p (@$previous) {
                    my $id = $p->id;
                    if ($subtrees->{ $id }) {
                        $redir = "/$id";
                        last;
                    }
                }
            }
            if ($can_post) {
                if ($thread->is_tree) {
                    $battie->set_local_redirect("/poard/thread/$thread_id$redir#ms_$msid");
                }
                else {
                    $battie->set_local_redirect("/poard/thread/$thread_id$redir?p=$page#ms_$msid");
                }
            }
            else {
                $battie->set_local_redirect("/poard/post_answer/$thread_id$redir?confirmation=1;msg_id=$msid");
            }
        }
        return;
    }
    my $previous = [];
    if ($thread->is_tree) {
        $previous = $self->parents_to_msg($battie, $schema, $msid);
    }
    else {
        $previous = [$schema->resultset('Message')->search({
            thread_id => $thread->id,
        }, { order_by => 'ctime desc', rows => 10 })];
    }
    my $user_infos = {};
    for my $prev (@$previous) {
        my $author_id = $prev->author_id or next;
        $user_infos->{ $author_id } = undef;
    }
    $self->fetch_user_infos($battie, $user_infos);
    for my $prev (@$previous) {
        my $ro = $self->render_message($battie, $prev, 'html', 0, 1);
        $ro->set_author($user_infos->{ $ro->author_id }) if $ro->author_id;
        $prev = $ro;
    }
    $data->{poard}->{correct_bbcode} = $from_form ? $correct_bbcode : 1;
    $data->{poard}->{correct_urls} = $from_form ? $correct_urls : 1;
    $data->{poard}->{previous} = $previous;
    $self->make_board_breadcrumb($battie, $board);
}

use constant CACHE_MSG_TIME => 60 * 60 * 24 * 40;
use constant CACHE_MSG_RECHECK_TIME => 60 * 60 * 24 * 3;
sub fetch_cached_messages {
    my ($self, $battie, $msg_ids) = @_;
    my @keys = map { "poard/msginthread/$_" } @$msg_ids;
    my $cached = $battie->from_cache(\@keys);
    my @entries = values %$cached;
    my @cached;
    my $now = time;
    ENTRY: for my $entry (@entries) {
        $entry->{updated} ||= $entry->{time};
        my $age = $now - $entry->{updated};
        if ($age > CACHE_MSG_RECHECK_TIME) {
            # cache old, re-check titles
            my $titles = $entry->{titles};
            if ($titles) {
                for my $type (keys %$titles) {
                    next if $type eq 'msg';
                    my $keys = $titles->{ $type };
                    for my $key (keys %$keys) {
                        my $value = $keys->{ $key };
                        warn __PACKAGE__.':'.__LINE__.": check title for $type $key\n";
                        my $title;
                        if ($type eq 'board') {
                            $title = $self->get_board_title_by_id($battie, $key);
                        }
                        elsif ($type eq 'thread') {
                            $title = $self->get_thread_title_by_id($battie, $key);
                        }
                        elsif ($type eq 'user') {
                            $title = $battie->module_call(login => 'get_user_nick_by_id', $key);
                        }
                        my $ck = "poard/msginthread/" . $entry->{msg}->id;
                        if ($title ne $value) {
                            warn __PACKAGE__.':'.__LINE__.": title $type $key outdated\n";
                            $battie->delete_cache($ck);
                            next ENTRY;
                        }
                        else {
                            my $expire = CACHE_MSG_TIME - ($now - $entry->{time});
                            $entry->{updated} = $now;
                            $battie->to_cache($ck, $entry, $expire);
                        }
                    }
                }
            }
        }
        push @cached, $entry->{msg};
    }
    return \@cached;
}

sub message_to_cache {
    my ($self, $battie, $message, $type, $attachments) = @_;
    my $board_id = $message->thread->board_id;
    my $msg_id = $message->id;
    my $params = {};
    my $start = [gettimeofday];
    my $msg_ro = $self->render_message_for_cache($battie, $message, $attachments, $params);
    $self->_times_for_cache($msg_ro);
    my $titles = $params->{titles};
    my $tag_info = $params->{tag_info};
    my $method = $type eq 'set' ? "to_cache" : "to_cache_add";
    my $now = time;
    my $entry = {
        msg => $msg_ro,
        time => $now,
        updated => $now,
        titles => $titles,
        tag_info => $tag_info,
    };
    $battie->$method("poard/msginthread/$msg_id", $entry, time + CACHE_MSG_TIME);
    my $msg_codes;
    my $syntax_h = 0;
    my $code_count = $tag_info->{code} || 0;
    if ($code_count) {
        my @codes = [];
        my $bbcode = $message->message;
        my $tree =  $battie->get_render->parse_message($bbcode);
        for my $i (0 .. $code_count-1) {
            my $count = 0;
            my $tag = $battie->get_render->find_tag($tree, [qw/ code perl /] => $i, \$count);
            my $attr = $tag->get_attr->[0];
            if ($tag->get_name eq 'perl' or ($tag->get_name eq 'code' and $attr)) {
                $syntax_h++;
            }
            my $content = $tag->get_content;
            my $raw = join '', @$content;
            $raw .= "\n" unless $raw =~ m/\n\z/;
            $codes[$i] = {
                name => $tag->get_name,
                code => $raw,
            };
        }
        $msg_codes = {
            board_id => $board_id,
            thread_id => $message->thread_id,
            codes => \@codes,
            status => $message->status,
        };
        $battie->$method("poard/msgcodes/$msg_id", $msg_codes, time + CACHE_MSG_TIME);
    }
    my $e = tv_interval($start)*1000;
    my $l = sprintf "%.03f", length($message->message) / 1024;
    warn __PACKAGE__.':'.__LINE__.": cache message $msg_id ($l kb, $code_count codes, $syntax_h highlights) took $e ms\n";
    return wantarray ? ($msg_ro, $entry) : $msg_ro;
}

sub render_message_for_cache {
    my ($self, $battie, $message, $attachments, $params) = @_;
    my $schema = $self->schema->{poard};
    unless ($attachments) {
        if ($message->has_attachment) {
            $attachments = [$schema->resultset('Attachment')->search({
                    message_id  => $message->id,
                    deleted     => 0,
                },
                {
                    order_by => 'attach_id',
                    select => [qw/ meta size thumb type filename message_id attach_id /],
                })->all];
        }
    }
    my $msg_ro = $self->render_message($battie, $message, 'html', 0, 1, $attachments, $params);
    return $msg_ro;
}


sub update_subtrees {
    my ($self, $battie, $thread, $msg) = @_;
    return unless $thread->is_tree;
    my $schema = $self->schema->{poard};
    my @msgs = map {
        $_->readonly([qw/ id lft rgt title ctime mtime /])
    } $schema->resultset('Message')->search({
            thread_id => $thread->id,
        }, {
            select => [qw/ id lft rgt title ctime mtime /],
            order_by => 'lft asc',
        })->all;
    my %subtrees;
    $self->filter_subtrees(\@msgs, \%subtrees);

    my $meta = $thread->meta;
    if (keys %subtrees > 1) {
        $meta ||= {};
        $meta->{subtrees} = \%subtrees;
    }
    else {
        $meta->{subtrees} = undef;
    }
    $thread->meta($meta);
}

sub filter_subtrees {
    my ($self, $msgs, $subtrees, $p) = @_;
    my @root;
    my %tmp;
    for (my $i = 0; $i < @$msgs; $i++) {
        my $m = $msgs->[$i];
        my $title = $m->title;
        my $id = $m->id;
        my ($lft, $rgt) = ($m->lft, $m->rgt);
        my $children = ($rgt - $lft - 1) / 2;
        if ($i != 0 and defined $title) {
            push @{ $tmp{$id} }, @$msgs[$i .. $i + $children];
            $i += $children;
            next;
        }
        push @root, $m;
    }
    my $max_mtime = 0;
    for my $m (@root) {
        my $mtime = ($m->mtime || $m->ctime)->epoch;
        $max_mtime = $mtime if $mtime > $max_mtime;
    }
    my $title = $root[0]->title;
    my $count = ($root[0]->rgt - $root[0]->lft - 1) / 2;
    if ($title) {
        $title = encode_utf8($title);
    }
    $subtrees->{ $root[0]->id } = {
        mtime => $max_mtime,
        title => $title,
        count => $count,
        $p ? (parent => $p) : (),
    };
    for my $key (keys %tmp) {
        my $list = $tmp{$key};
        $self->filter_subtrees($list, $subtrees, $msgs->[0]->id);
    }
}

sub make_board_breadcrumb {
    my ($self, $battie, $board) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $board_id = ref $board ? $board->id : $board;
    my $p = $self->parents_to_board($battie, $schema, 1, $board_id);
    for my $parent (@$p[1..$#$p]) {
        $battie->crumbs->append($parent->name, "poard/start/" . $parent->id);
    }
    if (ref $board) {
        if ($board->is_leaf) {
            $battie->crumbs->append($board->name, "poard/board/" . $board->id) if ref $board;
        }
        else {
            $battie->crumbs->append($board->name, "poard/start/" . $board->id) if ref $board;
        }
    }
}

sub expire_cache {
    my ($self, $battie, $thread) = @_;
    return;
    my @cache_expire;
    my $ids = $thread->search_related('messages', undef, {
        select => 'me.id',
    });
    while (my $next = $ids->next) {
        push @cache_expire, $next->id;
    }
    for my $id (@cache_expire) {
        #warn __PACKAGE__.':'.__LINE__.": expire $id\n";
        $battie->module_call(cache => 'delete_cache', 'poard/messages/'.$id);
    }
}

sub update_user_settings {
    my ($self, $battie, $userid) = @_;
    # we have a guest
    return unless $userid;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $uschema = $self->schema->{user};
    my $settings = $uschema->resultset('Settings')->find({user_id => $userid});
    unless ($settings) {
        $settings = $uschema->resultset('Settings')->create({user_id => $userid});
    }
    my $count = $schema->resultset('Message')->count({
            author_id => $userid,
            status => ['active', 'deleted'],
        });
    $settings->update({messagecount => $count});
    $battie->delete_cache('poard/user_info/' . $userid);
}

sub poard__mod_undelete_thread {
    my ($self, $battie) = @_;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $thread = $self->check_existance($battie, Thread => $id);
    $self->exception("Argument", "Thread '$id' was not deleted") unless $thread->status eq 'deleted';
    my $data = $battie->get_data;
    if ($submit->{undelete} and not $battie->valid_token) {
        delete $submit->{undelete};
        $data->{poard}->{error}->{token} = 1;
    }
    if ($submit->{undelete}) {
        my $trash = $schema->resultset('Trash')->find({thread_id => $id});
        $thread->status('active');
        $thread->mtime(\'mtime');
        $thread->update;
        $trash->delete;
        my $search = $thread->search_related('messages');
        my $updated = $search->update({
                mtime => \'mtime',
                status => 'active',
            });
        $battie->set_local_redirect("/poard/thread/$id");
        $battie->writelog($thread, "undelete $updated messages");
        $battie->module_call(cache => 'delete_cache', 'poard/thread/'.$id);
        $self->update_search_index($battie, update => thread => $thread->id);
        return;
    }
}

sub poard__mod_undelete_message {
    my ($self, $battie) = @_;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $message = $schema->resultset('Message')->find($id);
    $self->exception("Argument", "Message '$id' does not exist") unless $message;
    $self->exception("Argument", "Message '$id' was not deleted") unless $message->status eq 'deleted';
    if ($submit->{undelete}) {
        $battie->require_token;
        my $trash = $schema->resultset('Trash')->find({msid => $id});
        my $thread = $message->thread;
        unless ($trash) {
            $self->exception("Argument", "Cannot undelete message of deleted thread")
                if $thread->status eq 'deleted';
        }
        $message->status('active');
        $message->mtime(\'mtime');
        $message->update;
        $message->discard_changes;
        $self->write_message_log($battie, $schema, {
                msg_id          => $message->id,
                user_id         => $battie->get_session->userid,
                action          => 'undelete_message',
            });
        $trash->delete;
        $battie->set_local_redirect("/poard/message/$id");
        $battie->writelog($message);
        #$battie->module_call(cache => 'delete_cache', 'poard/messages/'.$id);
        $thread->discard_changes;
        $self->delete_thread_cache($battie, $thread);
        $self->reset_thread_cache($battie, $thread);
        $self->update_search_index($battie, update => message => $message->id);
        $self->message_to_cache($battie, $message, 'set');
        return;
    }
}

sub poard__admin_really_delete {
    my ($self, $battie) = @_;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    my ($what) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    if ($submit->{delete}) {
        $battie->require_token;
    }
    my @trash_ids = $request->param('trash.id');
    @trash_ids = @trash_ids[0..19] if @trash_ids > 20;
    if ($submit->{delete} and $what =~ m/^(threads|messages)$/) {
        eval {
            $schema->txn_do(sub {
                my @trash = $schema->resultset('Trash')->search({
                    id => [@trash_ids],
                }, { for => 'update' })->all;
                my %uids;
                my @tids;
                if ($what eq 'threads') {
                    for my $trash (@trash) {
                        my $thread = $schema->resultset('Thread')
                            ->find($trash->thread_id, { for => 'update' }) or next;
                        # TODO not implemented yet
                        next if $thread->is_survey;
                        push @tids, $thread->id;

                        $trash->delete;
                    }

                    # delete messages
                    my $msgs = $schema->resultset('Message')->search({
                        thread_id => [@tids],
                    }, { for => 'update' });
                    while (my $msg = $msgs->next) {
                        my $author = $msg->author_id or next;
                        $uids{$author}++;
                    }
                    $msgs->delete;

                    # delete read messages
                    my $read = $schema->resultset('ReadMessages')->search({
                            thread_id => [@tids],
                        })->delete;

                    $schema->resultset('Thread')->search({
                        id => [@tids],
                    })->delete;

                    # TODO delete subscriptions

                    # update user article count
                    for my $uid (keys %uids) {
                        $self->update_user_settings($battie, $uid);
                    }
                }
                elsif ($what eq 'messages') {
                    for my $trash (@trash) {
                        my $msg = $schema->resultset('Message')
                            ->find($trash->msid, { for => 'update' }) or next;

                        my $thread = $msg->thread;
                        # only delete leaves
                        if ($thread->is_tree) {
                            my ($lft, $rgt) = ($msg->lft, $msg->rgt);
                            next if ($rgt - $lft) > 1;
                            my $prev = $schema->resultset('Message')->search({
                                    thread_id   => $thread->id,
                                    lft         => { '>', $lft },
                                });
                            $prev->update({
                                    lft => \'lft - 2',
                                });
                            my $post = $schema->resultset('Message')->search({
                                    thread_id   => $thread->id,
                                    rgt         => { '>', $rgt },
                                });
                            $post->update({
                                    rgt => \'rgt - 2',
                                });
                        }
                        else {
                            next if $msg->position == 0;
                        }

                        $msg->delete;
                        $thread->update({
                                messagecount    => \'messagecount - 1',
                                mtime           => \'mtime',
                            });
                        $trash->delete;
                    }
                }
            });
        };
        if (my $e = $@) {
            warn __PACKAGE__.':'.__LINE__.": $e\n";
            $self->exception(Transaction => "Transaction failed");
        }
        $battie->writelog(undef, "Deleted threads from trash");
        my $redir = "/poard/view_trash/$what";
        $battie->set_local_redirect($redir);
    }
}

sub poard__mod_delete_thread {
    my ($self, $battie) = @_;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $thread = $self->check_existance($battie, Thread => $id);
    $self->exception("Argument", "Thread '$id' is already deleted") if $thread->status eq 'deleted';
    $self->check_visibility($battie, $thread);
    my $comment = $request->param('comment');
    my $other = $request->param('other');
    if ($submit->{delete} and not $comment) {
        $submit->{preview} = delete $submit->{delete};
    }
    if ($submit->{delete} and not $battie->valid_token) {
        $submit->{preview} = delete $submit->{delete};
    }
    if ($submit->{preview}) {
        $battie->get_data->{poard}->{thread} = $thread->readonly;
    }
    elsif ($submit->{delete}) {
        $thread->status('deleted');
        $thread->mtime(\'mtime');
        $thread->update;
        my $messages = $thread->search_related(messages => {
                status => { '!=' => 'deleted' },
            });
        $messages->update({
            mtime => \'mtime',
            status => 'deleted',
        });
        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$comment], ['comment']);
        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$other], ['other']);
        if ($comment eq 'other:' and defined $other) {
            $comment .= " $other";
        }
        my $trash = $schema->resultset('Trash')->create({
                thread_id  => $thread->id,
                deleted_by => $battie->get_session->userid,
                comment    => $comment,
        });
        # TODO
        # update posting count in user Settings
        $battie->writelog($thread);
        $self->update_search_index($battie, delete => thread => $thread->id);
        $thread->discard_changes;
        $self->delete_thread_cache($battie, $thread);
        $self->reset_thread_cache($battie, $thread);
        $battie->set_local_redirect("/poard/board/".$thread->board->id);
        return;

    }
}

sub update_search_index {
    my ($self, $battie, $type, %args) = @_;
    my $search_conf = $self->get_search;
    return unless $search_conf->{class} eq 'KinoSearch';
    my $path = $search_conf->{index};
    open my $fh, '>>', "$path/to_update.csv" or do {
        warn "!!! Could not open $path/to_update.csv: $!";
        return;
    };
    flock $fh, LOCK_EX;
    seek $fh, 0, SEEK_END;
    if ($type eq 'delete') {
        if (my $tid = $args{thread}) {
            print $fh "delete;thread;$tid\n";
        }
        elsif (my $mid = $args{message}) {
            print $fh "delete;msg;$mid\n";
        }
    }
    elsif ($type eq 'update') {
        if (my $tid = $args{thread}) {
            print $fh "update;thread;$tid\n";
        }
        elsif (my $mid = $args{message}) {
            print $fh "update;msg;$mid\n";
        }
    }
    close $fh;
    return;
    #warn __PACKAGE__.':'.__LINE__.": !!!! OPEN invindexer\n";
    my $indexer = KinoSearch::Indexer->new(
        index => $path,
    );
    if ($type eq 'delete') {
        if (my $tid = $args{thread}) {
            warn __PACKAGE__.':'.__LINE__.": DELETING thread $tid from index\n";
            $indexer->delete_by_term( thread_id => $tid );
        }
        elsif (my $mid = $args{message}) {
            warn __PACKAGE__.':'.__LINE__.": DELETING message $mid from index\n";
            $indexer->delete_by_term( id => $mid );
        }
        $indexer->finish;
    }
    elsif ($type eq 'update') {
        my $schema = $self->schema->{poard};
        if (my $tid = $args{thread}) {
            my $thread = $schema->resultset('Thread')->find($tid);
            my $msgs = $thread->search_related('messages',
                {
                    status => {'!=' => 'deleted'},
                }
            );
            while (my $msg = $msgs->next) {
                my $doc = $self->make_search_document($battie, message => $msg);
                $indexer->add_doc($doc) if $doc;
            }
        }
        elsif (my $mid = $args{message}) {
            my $doc = $self->make_search_document($battie, message => $mid);
            $indexer->add_doc($doc) if $doc;
        }
        $indexer->finish;
    }
    else {
        warn __PACKAGE__.':'.__LINE__.": !!!!!!!!!!!!!!!!!!!!!\n";
        $indexer->finish;
    }
}

sub reinitialize_indexer {
    my ($self) = @_;
    my $search_conf = $self->get_search;
    return unless $search_conf->{class} eq 'KinoSearch';
    require WWW::Battie::Search::Poard;
    require KinoSearch::Searcher;
    require KinoSearch::Analysis::PolyAnalyzer;
    require KinoSearch::Search::SortSpec;
    require KinoSearch::Indexer;
    my $path = $search_conf->{index};
    my $last_init = $search_conf->{last_init};
    my $now = time;
    return if $now < $last_init + 30;
    my $searcher = KinoSearch::Searcher->new(
        index => $path,
    );
    my $analyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        language => 'de',
    );
    my $query_parser = KinoSearch::QueryParser->new(
        analyzer    => $analyzer,
        schema      => WWW::Battie::Search::Poard->new,
        fields      => [ 'body', 'title' ],
    );
    my $query_parser_title = KinoSearch::QueryParser->new(
        analyzer    => $analyzer,
        schema      => WWW::Battie::Search::Poard->new,
        fields      => [ 'title' ],
    );
    $search_conf->{searcher} = $searcher;
    $search_conf->{query_parser} = $query_parser;
    $search_conf->{query_parser_title} = $query_parser_title;
    $search_conf->{last_init} = $now;
}

sub make_search_document {
    my ($self, $battie, %args) = @_;
    my $schema = $self->schema->{poard};
    if (my $mid = $args{message}) {
        my $msg;
        if (ref $mid) {
            $msg = $mid;
        }
        else {
            $msg = $schema->resultset('Message')->find($mid);
        }
        return unless $msg->status eq 'active';
        my $thread = $msg->thread;
        my $title = $thread->title;
        my $bodytext = $msg->message;
        my $author_name = $msg->author_name;
        $author_name = '' unless defined $author_name;
        my $author_id = $msg->author_id || 0;
        my $doc = {
            title       => $title,
            body        => $bodytext,
            id          => $msg->id,
            date        => ($msg->mtime || $msg->ctime)->epoch,
            thread_id   => $msg->thread->id,
            board_id    => $msg->thread->board->id,
            author_id   => $author_id,
            author_name => $author_name,
        };
        return $doc;
    }
}

sub poard__mod_delete_message {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $response = $battie->response;
    $response->set_no_cache(1);
    $self->init_db($battie);
    my $args = $request->get_args;
    my $schema = $self->schema->{poard};
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    my $message = $schema->resultset('Message')->find($id);
    $self->exception("Argument", "Message '$id' does not exist") unless $message;
    if ($submit->{delete}) {
        my $data = $battie->get_data;
        $data->{poard}->{nojs} = 1;
        my $message_ro = $message->readonly;
        $data->{poard}->{message} = $message_ro;
        return;
    }
    elsif ($submit->{reallydelete}) {
        $battie->require_token;
        my $comment = $request->param('comment');
        $self->delete_message($battie, $message,$comment);
        my $thread = $message->thread;
        $message->discard_changes;
        if ($request->param('ajax')) {
            my $message_ro = $message->readonly;
            my $approver = $battie->module_call(login => 'get_user_by_id', $message->approved_by);
            $message_ro->set_approved_by($approver->readonly) if $approver;
            my $data = $battie->get_data;
            if ($message_ro->is_deleted) {
                my $trash = $schema->resultset('Trash')->find({msid => $id});
                my $trash_ro = $trash->readonly;
                my $del_by = $trash->deleted_by;
                my $deletor = $battie->module_call(login => 'get_user_by_id', $del_by);
                $trash_ro->set_deleted_by($deletor->readonly);
                $data->{poard}->{trash} = $trash_ro;
            }
            $data->{poard}->{message} = $message_ro;
            $data->{main_template} = "poard/ajax.html";
        }
        else {
            my $thread_id = $thread->id;
            $battie->set_local_redirect("/poard/thread/$thread_id");
        }
        $battie->delete_cache('poard/onhold');
        $thread->discard_changes;
        $self->delete_thread_cache($battie, $thread);
        $self->reset_thread_cache($battie, $thread);
        $self->message_to_cache($battie, $message, 'set');
    }
}

sub delete_message {
    my ($self, $battie, $message, $comment) = @_;
    my $schema = $self->schema->{poard};
    my $thread = $message->thread;
    $self->check_visibility($battie, $thread);
    $message->status('deleted');
    $message->lasteditor($battie->get_session->userid);
    $message->update;
    $self->write_message_log($battie, $schema, {
            msg_id          => $message->id,
            user_id         => $battie->get_session->userid,
            edit_comment    => $comment,
            action          => 'delete_message',
        });
    if ($message->author_id) {
        $self->update_user_settings($battie, $message->author_id);
    }
    $thread->messagecount(\'messagecount - 1');
    $thread->update;
    $battie->writelog($message);
    #$battie->module_call(cache => 'delete_cache', 'poard/messages/'.$message->id);
    my $trash = $schema->resultset('Trash')->create({
        msid => $message->id,
        deleted_by => $battie->get_session->userid,
        comment => $comment,
    });
    $self->update_search_index($battie, delete => message => $message->id);
}

sub check_board_group {
    my ($self, $battie, @board) = @_;
    my @allowed;
    my $roles = $battie->get_allow->get_roles;
    for my $board (@board) {
        my $group = $board->grouprequired;
        push @allowed, $board if (!$group or $roles->{ $group } );
    }
    return @allowed;
}

sub poard__view_message {
    shift->poard__message(@_)
}
sub poard__message {
    my ($self, $battie) = @_;
    $self->load_db($battie);
    my $request = $battie->request;
    # small view ony with module navigation
    $battie->response->set_needs_navi(0);
    $battie->get_data->{main_template} = "poard/main_message.html";
    $battie->set_view('small');
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id, @more_args) = @$args;
    if ($id =~ tr/0-9//c) {
        $battie->not_found_exception("Message '$id' does not exist");
    }
    my $data = $battie->get_data;

    my $showcode = 0;
    if (@more_args >=2 and $more_args[0] eq 'code') {
        my $filename = $more_args[1];
        if ($filename =~ m/^code_(\d+)_(\d+)\.txt\z/) {
            my ($cmsid, $code_id) = ($1, $2);
            if ($cmsid == $id) {
                $showcode = $code_id;
            }
        }
    }
    else {
        # legacy
        $showcode = $request->param('code_id') || 0;
        $showcode =~ tr/0-9//cd;
    }
    my $thread_id;
    my $thread_ro;
    if ($showcode) {
        $showcode--;
        my $raw;
        my $cached = $battie->from_cache("poard/msgcodes/$id");
        my $count;
        my $board_id;
        $data->{main_template} = undef;
        if ($cached) {
            my $status;
            if ((ref $cached) eq 'ARRAY') {
                warn __PACKAGE__.':'.__LINE__.": showcode msg $id $showcode legacy\n";
                my $ck = "poard/msginthread/$id";
                my $msg_cache_entry = $battie->from_cache($ck);
                my $msg_ro = $msg_cache_entry->{msg};
                $thread_id = $msg_ro->thread_id;
                $thread_ro = $self->fetch_thread_header($battie, $thread_id);
                $board_id = $thread_ro->board_id;
                $status = $msg_ro->status;
                $cached = {
                    status => '',
                    codes => $cached,
                };
            }
            else {
                $thread_id = $cached->{thread_id};
                $status = $cached->{status};
                $board_id = $cached->{board_id};
            }
            $count = $showcode;
            $raw = $cached->{codes}->[$showcode]->{code};
            if ($status eq 'deleted') {
                $battie->response->set_no_cache(1);
                unless ($battie->get_allow->can_do(poard => 'view_trash')) {
                    $battie->not_found_exception("Message '$id' is deleted");
                }
            }
        }
        else {
            $self->init_db($battie);
            my $schema = $self->schema->{poard};
            warn __PACKAGE__.':'.__LINE__.": showcode msg $id $showcode\n";
            my $message = $schema->resultset('Message')->find($id,
                {
                    select => [qw/ me.id me.thread_id me.message /],
                })
                or $battie->not_found_exception("Message '$id' does not exist");
            $thread_id = $message->thread_id;
            $thread_ro = $self->fetch_thread_header($battie, $thread_id);
            $board_id = $thread_ro->board_id;
            my $bbcode = $message->message;
            my $tree =  $battie->get_render->parse_message($bbcode);
            $count = 0;
            my $tag = $battie->get_render->find_tag($tree, [qw/ code perl /] => $showcode, \$count);
            if ($tag) {
                my $content = $tag->get_content;
                $raw = join '', @$content;
                $raw .= "\n" unless $raw =~ m/\n\z/;
            }
        }
        my $board = $self->fetch_boards($battie, $board_id);
        $battie->not_found_exception("Message '$id' is not visible by you", [])
            unless $self->check_board_group($battie, $board);
        $battie->response->set_content_type('text/plain');
        $battie->response->set_encoding('utf-8');
        $battie->response->set_output($raw);
        $battie->response->get_header->{'Content-Disposition'}
            = "attachment; filename=code_${id}_${\($count+1)}.txt";
        return;
    }



    my $ck = "poard/msginthread/$id";
    my $msg_cache_entry = $battie->from_cache($ck);
    my $msg_ro;
    if ($msg_cache_entry) {
        $msg_ro = $msg_cache_entry->{msg};
    }
    else {
        $self->init_db($battie);
        my $schema = $self->schema->{poard};
        my $message = $schema->resultset('Message')->find($id,
            {
#                prefetch => 'thread',
                select => [qw/
                        me.id me.mtime me.ctime me.author_name me.author_id
                        me.thread_id me.title me.status me.message me.position
                        me.lasteditor me.approved_by me.changelog me.has_attachment
                /],
            })
            or $battie->not_found_exception("Message '$id' does not exist");
        my $attachments;
        if ($message->has_attachment) {
            my @attachments = $schema->resultset('Attachment')->search({
                    message_id  => $message->id,
                    deleted     => 0,
                },
                {
                    order_by => 'attach_id',
                    select => [qw/ meta size thumb type filename message_id attach_id /],
                })->all;
            $attachments = \@attachments;
        }
        ($msg_ro, $msg_cache_entry) = $self->message_to_cache($battie, $message, 'add', $attachments);
    }
    if ($msg_ro->status eq 'deleted') {
        # could we send a status 404?
        $battie->response->set_no_cache(1);
        unless ($battie->get_allow->can_do(poard => 'view_trash')) {
            $self->exception("Argument", "Message '$id' is deleted");
        }
    }
    $thread_ro = $self->fetch_thread_header($battie, $msg_ro->thread_id);
    my $board = $self->fetch_boards($battie, $thread_ro->board_id);
    $thread_ro->set_board($board);
    $self->check_visibility($battie, $thread_ro);
    if (not $battie->session->userid and $request->is_mtime_satisfying($msg_ro->mtime_epoch||$msg_ro->ctime_epoch)) {
        $battie->response->set_status('Not modified');
        return;
    }
    my $loadmore = $request->param('more_id') || 0;
    $loadmore =~ tr/0-9//cd;
    $self->init_seo($battie, $thread_ro->board);
    if ($loadmore) {
        $self->init_db($battie);
        my $schema = $self->schema->{poard};
        my $message = $schema->resultset('Message')->find($id,
            {
                select => [qw/ me.id me.thread_id me.message /],
            })
            or $battie->not_found_exception("Message '$id' does not exist");
        my $bbcode = $message->message;
        my $tree =  $battie->get_render->parse_message($bbcode);
        if ($loadmore) {
            $data->{main_template} = "poard/message_more.html";
            my $count = 0;
            my $tag = $battie->get_render->find_tag($tree, more => $loadmore-1, \$count);
            if ($tag) {
                $tag = Parse::BBCode::Tag->new({
                        name    => '',
                        content => $tag->get_content,
                    });
                $bbcode = $tag->raw_text;
                $tree = $tag;
                my $rendered = $battie->get_render->render_message_html($tree, $message->id);
                $data->{poard}->{message}->{more} = $rendered;
                return;
            }
        }
    }

    if ($msg_cache_entry->{tag_info}->{more}) {
        $self->init_db($battie);
        my $schema = $self->schema->{poard};
        my $message = $schema->resultset('Message')->find($id,
            {
                select => [qw/
                        me.id me.thread_id me.message
                /],
            })
            or $battie->not_found_exception("Message '$id' does not exist");
        my $re = $battie->get_render->render_message_html($message->message, $id, 0, {});
        $msg_ro->set_rendered($re);
    }
    my $author_id = $msg_ro->author_id;
    my $approved_by = $msg_ro->approved_by;
    my $user_infos = {
        $author_id ? ($author_id => undef) : (),
        $approved_by ? ($approved_by => undef) : (),
    };
    $self->fetch_user_infos($battie, $user_infos);
    if ($author_id) {
        $self->msg_author($msg_ro, $user_infos->{ $author_id });
    }
    if ($approved_by) {
        $msg_ro->set_approved_by($user_infos->{ $approved_by });
    }

    $thread_ro->set_board($board);
    $msg_ro->set_thread($thread_ro);
    my $uid = $battie->session->userid;
    my $meta = $thread_ro->meta || {};
    # TODO subtrees
    if (0 and $thread_ro->is_tree and $uid and not $meta->{subtrees}) {
        $self->init_db($battie);
        my $schema = $self->schema->{poard};
        my $last_read = $schema->resultset('ReadMessages')->search({
                user_id => $uid,
                thread_id => $thread_ro->id,
            }, {
                rows => 1,
            })->single;
        my $first_id = $schema->resultset('Message')->search({
                thread_id => $thread_ro->id,
                lft => 1,
            }, {
                rows => 1,
                'select' => [qw/ id mtime lft rgt /],
            })->single->id;
        my @msgs = $schema->resultset('Message')->search({
                thread_id => $thread_ro->id,
                mtime => { '>' => $last_read->mtime },
            },
            {
                order_by => 'mtime asc',
                'select' => [qw/ id mtime lft rgt /],
            })->all;
        if (@msgs) {
            my $meta = $last_read->meta || {};
            my $root = $meta->{$first_id} || {};
            unless (ref($root) eq 'HASH') {
                $root = {
                    mtime => $root,
                    m => [],
                };
            }
            my $last_mtime = $last_read->mtime;
            my $read_msgs = $root->{m};
            my %read = map { $_ => 1 } @$read_msgs;
            $read{ $msg_ro->id }++;
            for my $msg (@msgs) {
                my $test = $msg->id;
                if ($read{ $msg->id }) {
                    $last_mtime = $msg->mtime;
                    delete $read{ $msg->id };
                }
                else {
                    last;
                }
            }
            $root->{m} = [keys %read];
            $meta->{$first_id} = $root;
            if (@{ $root->{m} }) {
                # read messages left
                $last_read->update({
                        mtime => $last_mtime,
                        meta => $meta,
                    });
            }
            else {
                # no read messages left, threads is read completely
                $last_read->update({
                        mtime => $last_mtime,
                        meta => undef,
                    });
            }

        }

    }

    if ($request->param('type') || '' eq 'plain') {
        $battie->response->set_content_type('text/plain');
        my $re = $battie->get_render->render_message_text($msg_ro->message, $msg_ro->id);
        warn __PACKAGE__.':'.__LINE__.": << $re >>\n";
        $msg_ro->set_rendered($re);
        $data->{main_template} = "poard/message_plain.html";
    }
    $data->{poard}->{message} = $msg_ro;
    $data->{poard}->{thread} = $thread_ro;
    $battie->response->set_last_modified($msg_ro->mtime_epoch || $msg_ro->ctime_epoch);
    my $title = $thread_ro->title;
    if ($thread_ro->solved) {
        $title .= ' (' . $battie->translate('poard_solved') . ')';
    }
    $data->{subtitle} = $self->make_subtitle(message =>
        board  => $thread_ro->board->name,
        thread => $title,
        id     => $msg_ro->id,
    );
}

sub fetch_thread_header {
    my ($self, $battie, $thread_id) = @_;
    my $tck = "poard/thread_header/$thread_id";
    my $thread_ro = $battie->from_cache($tck);
    unless ($thread_ro) {
        $self->init_db($battie);
        my $schema = $self->schema->{poard};
        my $thread = $schema->resultset('Thread')->find($thread_id);
        my $threads = $self->render_thread_headers($schema, $battie, [$thread]);
        $thread_ro = $threads->[0];
    }
    return $thread_ro;
}

sub init_seo {
    my ($self, $battie, $board) = @_;
    my $request = $battie->request;
    my $index = $board->get_bit_index();
    my $archive = $board->get_bit_archive();
    $index &&= !$request->param('battie_view');
    $archive &&= !$request->param('battie_view');
    $battie->response->set_no_index(!$index);
    $battie->response->set_no_archive(!$archive);
}

=pod

sub render_thread {
    my ($self, $battie, $thread) = @_;
    my $thread_ro = $thread->readonly([qw/ id title ctime board messagecount /]);
    my $uschema = $self->schema->{user};
    if ($thread->author_id) {
        my $user = $uschema->resultset('User')->search(
            { id => $thread->author_id},
            {
                'select' => [qw/ id nick /],
            })->single;
        return $thread_ro unless $user;
        $thread_ro->set_author($user->readonly([qw/ id nick /]));
    }
    else {
        $thread_ro->set_author_name($thread->author_name);
    }
    return $thread_ro;

}

=cut

sub view_thread {
    my ($self, $battie, %args) = @_;
    my $id = $args{id};
    if ($id =~ tr/0-9//c) {
        $battie->not_found_exception("Thread '$id' does not exist");
    }
    my $deleted = $args{delete};
    my $leaf = $args{leaf};
    my $update_read = $args{update_read};
    my $full = $args{full};
    my $request = $battie->request;
    my $read = $request->param('read') || 0;
    my $rows = $rows_in_thread;
    my $page = $request->pagenum(1000); # not more than 1000 pages;
    my $schema = $self->schema->{poard};
    my $thread_ck = "poard/thread_info/$id";
    my $thread_ro = $battie->from_cache($thread_ck);
    unless ($thread_ro) {
        my $thread = $self->check_existance($battie, Thread => $id);
        $thread_ro = $self->reset_thread_cache($battie, $thread, "add");
    }
    my $board = $self->fetch_boards($battie, $thread_ro->board_id);
    my $view_deleted = $deleted && $battie->get_allow->can_do(poard => 'view_trash');
    $self->exception("Argument", "Thread '$id' is deleted") if ($thread_ro->status eq 'deleted' and not $deleted);
    $thread_ro->set_board($board);
    $self->check_visibility($battie, $thread_ro);
    my $tids;
    my $rendered_messages = [];
    my $last_mtime = 0;
    $battie->timer_step("after fetch thread");

    my $uid = $battie->session->userid;
    my $tid = $thread_ro->id;
    if ($thread_ro->is_tree) {
        my $last_read;
        $self->render_subtrees($thread_ro);
        $battie->timer_step("after subtrees");
        if ($battie->session->userid) {
            my $thread_read = $self->mark_read_threads($battie, [$thread_ro]);
            $last_read = $thread_read->{"poard/read_thread/$uid/$tid"};

        }
        $battie->timer_step("after mark read");
        my $last_read_mtime;
        if ($leaf) {
            $leaf = $schema->resultset('Message')->find($leaf);
            if (!$leaf or $leaf->thread_id != $id) {
                $leaf = undef;
            }
            $self->exception(Argument => "Message does not exist") unless $leaf;
        }
        if ($leaf) {
            my $update = 0;
            if ($last_read) {
                my $subtrees = ($thread_ro->meta || {})->{subtrees};
#                warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$subtrees], ['subtrees']);
                my $meta = $last_read->meta || {};
#                warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$meta], ['meta']);
                for my $id (keys %$subtrees) {
#                    warn __PACKAGE__.':'.__LINE__.": id $id\n";
                    my $tree = $subtrees->{$id};
                    my $rid = $id;
                    my $m;
                    while ($rid) {
                        if ($meta->{$rid}) {
                            $m = $meta->{$rid};
                            last;
                        }
                        else {
                            $rid = $tree->{parent};
                            $tree = $subtrees->{ $rid } if $rid;
                        }
                    }
                    $m ||= $last_read->mtime_epoch;
                    if ($m != $meta->{$id}) {
                        $meta->{$id} = $m;
                        $update = 1;
                    }
                }
#                warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$meta], ['meta']);
                if ($update) {
                    warn __PACKAGE__.':'.__LINE__.": update (leaf) for $uid/$tid/$leaf\n";
                    $schema->resultset('ReadMessages')->find({
                            user_id => $uid,
                            thread_id => $tid,
                        })->update({
                            meta => $meta,
                        });
                    my $ck = "poard/read_thread/$uid/$tid";
                    $battie->delete_cache($ck);
                }
#                $last_read_mtime = DateTime->from_epoch( epoch => $meta->{$leaf->id} );
                $last_read_mtime = $meta->{$leaf->id};
            }
        }
        else {
            $last_read_mtime = $last_read ? $last_read->mtime_epoch : 0;
        }

#        my $mtime = $thread_ro->mtime || $thread_ro->ctime;

        my $cached_tree;
        my $cached_tree_small;
        # fetch messages
        my $ck = "poard/threadtree/$id";
        $ck .= "/" . $leaf->id if $leaf;
#        my $ck_small = "poard/threadtree_mini/$id";
        $battie->timer_step("before from cache");
        my $user_infos;
        my $first_time;
        my $last_time;
        if ($full) {
            $cached_tree = $battie->from_cache($ck);
            $battie->timer_step("after from cache");
            if ($cached_tree) {
                $rendered_messages = $cached_tree->{messages};
#                $user_infos = $cached_tree->{user_infos} || {};
                $first_time = $cached_tree->{first_time};
                $last_time = $cached_tree->{last_time};
            }
            else {
            }
        }
        else {
#            $cached_tree_small = $battie->from_cache($ck_small);
            $battie->timer_step("after from cache small");
            if ($cached_tree_small) {
                $rendered_messages = $cached_tree_small->{messages};
#                $user_infos = $cached_tree_small->{user_infos} || {};
                $first_time = $cached_tree_small->{first_time};
                $last_time = $cached_tree_small->{last_time};
            }
        }

#        my $ckuser = "poard/message_authors/$id";
#        my $save_user_infos = 0;
#        my $save_rendered = $cached_tree ? 0 : 1;
#        warn __PACKAGE__.':'.__LINE__.": !!!!!!!!!! @$rendered_messages\n";
        if (@$rendered_messages) {
        }
        else {
            $rendered_messages = [];
            my @msgs = $schema->resultset('Message')->search({
                thread_id => $thread_ro->id,
            }, {
                select => [qw/ id lft rgt /],
            });
            my @msg_ids;
            my %ids_to_fetch;
            for my $msg (@msgs) {
                my ($id, $lft, $rgt) = ($msg->id, $msg->lft, $msg->rgt);
                $ids_to_fetch{ $id } = [$lft, $rgt];
                push @msg_ids, $id;
            }
            my $cached_msgs = $self->fetch_cached_messages($battie, \@msg_ids);
            for my $msg (@$cached_msgs) {
                my $c = $ids_to_fetch{ $msg->id };
                my ($lft, $rgt) = @$c;
                $msg->set_lft($lft);
                $msg->set_rgt($rgt);
                delete $ids_to_fetch{ $msg->id };
            }
            @msgs = @$cached_msgs;
            if (keys %ids_to_fetch) {
                my @uncached = $schema->resultset('Message')->search({
                        thread_id => $thread_ro->id,
                        id => { IN => [keys %ids_to_fetch] },
                    },
                );
                push @msgs, @uncached;
            }
            @msgs = sort { $a->lft <=> $b->lft } @msgs;
            my $lvl;
            my ($TEXT, $LFT, $RGT);
            my @l;
            my $last_level = 1;

            my @titles;
            if ($leaf) {
                my @tmp = @msgs;
                @msgs = ();
                my $push = 0;
                for my $m (@tmp) {
                    if ($m->id == $leaf->id) {
                        $push = $m->rgt;
                    }
                    elsif ($push and $m->rgt > $push) {
                        last;
                    }
                    push @msgs, $m if $push;
                }
            }
            my $skip = -1;
            my $root_title = $msgs[0]->title;
            $root_title = '' unless defined $root_title;
            my %attach_msgs;
            for my $msg (@msgs) {
                next if ref($msg) eq 'WWW::Poard::Model::Message::Readonly';
                if ($msg->has_attachment) {
                    $attach_msgs{ $msg->id } = undef;
                }
            }
            if (keys %attach_msgs) {
                my $attach_search = $schema->resultset('Attachment')->search({
                        message_id  => { IN => [keys %attach_msgs] },
                        deleted     => 0,
                    },
                    {
                        order_by => 'message_id, attach_id',
                    });
                while (my $attach = $attach_search->next) {
                    my $msid = $attach->message_id;
                    push @{ $attach_msgs{ $msid } }, $attach;
                }
            }
            for (my $i = 0; $i < @msgs; $i++) {
                my $msg = $msgs[$i];
                my $last = 1;
                my ($id, $lft, $rgt, $text) = ($msg->id, $msg->lft, $msg->rgt, $msg->message);
                my $title = $msg->title;
                $title = '' unless defined $title;
                if ($i <= $skip) {
#                    my $mtime = $msg->mtime_epoch || $msg->mtime || $msg->ctime_epoch || $msg->ctime;
#                    $mtime = $mtime->epoch if ref $mtime;
                    my $l = $rendered_messages->[-1];
#                    if ($mtime > $old_mtime) {
#                        $l->set_mtime($mtime);
#                    }
                    next;
                }
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
                        $last = 0 if @l && ($rgt + 1 < $l[-1]);
                        push @l, $rgt;
                    }
                }
                else {
                    @l = $rgt;
                }
                $RGT = $rgt;
                my $ro = $msg;
                unless (ref($msg) eq 'WWW::Poard::Model::Message::Readonly') {
                    my $attachments = $attach_msgs{ $msg->id };
                    $ro = $self->message_to_cache($battie, $msg, 'add', $attachments);
#                    $ro = $self->render_message($battie, $msg, 'html', 0, 1, $attachments);
                }
                else {
                    $self->_times_for_cache($msg);
                }
                my $is_leaf = $msg->is_leaf;
                if (length $title and $title ne $root_title) {
                    my $children = $ro->children_count;
                    $skip = $i + $children;
                    $is_leaf = 1;
                }
                $ro->set_level($#l);
                if (@$rendered_messages and @l < $last_level) {
                    my $down = $last_level - @l;
                    $ro->set_level_down([(1) x $down]);
                }
                $ro->set_leaf_posting($is_leaf);
                $last_level = @l;
                $ro->set_is_last($last);
#                $ro->set_thread($thread_ro);
                $msg = $ro;
                push @$rendered_messages, $ro;
            }
            $first_time = $rendered_messages->[0]->ctime_epoch;
            $last_time = $first_time;
            for my $ro (@$rendered_messages) {
                my $mtime = $ro->mtime_epoch || $ro->ctime_epoch;
                if ($mtime > $last_time) {
                    $last_time = $mtime;
                }
            }

            # render tree colors
            my $diff = ($last_time - $first_time) || 1;
            my $step_count = 8;
            $step_count = @$rendered_messages if @$rendered_messages < 8;

            my $step = (@$rendered_messages / $step_count) || 1;
            my $i = 0;
            for my $m (sort { $a->ctime_epoch <=> $b->ctime_epoch } @$rendered_messages) {
                my $age = $last_time - $m->ctime_epoch;
                my $level = $step ? int($i / $step) : 0;

                my $date_level = $request->param('date_level');
                if ($date_level) {
                    $date_level = 0 + $date_level;
                    if ($date_level <1 or $date_level > 5) {
                        $date_level = 1;
                    }
                }
                else {
                    $date_level = 2;
                }
                my $percent = $age / $diff * 100;
                my $log = $percent >=1 ? log($percent) : 1;
                $log /= $date_level;
                $log = 1 if $log < 1;
                $level /= ($log);
                #my $debug = sprintf "percent: %0.2f log: %0.2f level: %0.2f", $percent, $log, $level;
                #warn __PACKAGE__.':'.__LINE__.": $debug\n";
                $level = int($level);
                $m->set_age_level($level);
                $i++;
            }

            # collect message authors
            for my $m (@$rendered_messages) {
                my $author_id = $m->author_id;
                if ($author_id) {
                    $user_infos->{ $author_id } ||= undef;
                }
                my $approved = $m->approved_by;
                if ($approved) {
                    $user_infos->{ $approved } ||= undef;
                }
            }


            if (keys %$user_infos) {
                $battie->timer_step("before user infos");
                $self->fetch_user_infos($battie, $user_infos);
                $battie->timer_step("after user infos");
            }

            # set author infos
            for my $ro (@$rendered_messages) {
                if (my $author_id = $ro->author_id) {
                    my $user_ro = $user_infos->{ $author_id };
                    $self->msg_author($ro, $user_ro);
                }
                if (my $approved = $ro->approved_by) {
                    $ro->set_approved_by($user_infos->{ $approved });
                }
            }

            $cached_tree = {
                messages => $rendered_messages,
                first_time => $first_time,
                last_time => $last_time,
#                user_infos => $user_infos,
            };
            $battie->to_cache($ck, $cached_tree, 60 * 60 * 4);
#            warn __PACKAGE__.':'.__LINE__.": !!!!!!!!!!!\n";
            my @small_msgs;
#            for my $msg (@$rendered_messages) {
#                my $author = $msg->author;
#                my $small_author;
#                if ($author) {
#                    $small_author = ref($author)->new({
#                            nick => $author->nick,
#                        });
#                }
#                my $small = ref($msg)->new({
#                        id => $msg->id,
#                        title => $msg->title,
#                        level => $msg->level,
#                        author => $small_author,
#                        author_name => $msg->author_name,
#                        ctime => $msg->ctime,
#                        age_level => $msg->age_level,
#                        status => $msg->status,
#                    });
#                push @small_msgs, $small;
#            }
#            $cached_tree_small = {
#                messages => \@small_msgs,
#                first_time => $first_time,
#                last_time => $last_time,
##                user_infos => $user_infos,
#            };
#            $battie->to_cache($ck_small, $cached_tree_small, 60 * 3);
            unless ($full) {
                $rendered_messages = \@small_msgs;
            }
        }

        my (@folds, @stack);
        my $first_id = $rendered_messages->[0]->id;
        my $root_title = $rendered_messages->[0]->title;
        $root_title = '' unless defined $root_title;
        for my $ro (@$rendered_messages) {

            my $mtime = $ro->mtime_epoch || $ro->ctime_epoch;
            unless ($mtime) {
                $mtime = $ro->mtime || $ro->ctime;
                $mtime= $mtime->epoch if $mtime;
            }
#            if ($mtime->epoch > $last_time) {
#                $last_time = $mtime->epoch;
#            }

            # set read status
            if (!$last_read_mtime or $last_read_mtime < $mtime) {
                # mark message as new
                $ro->set_is_new(1);
            }
            if ($full) {
                my $isnew = $ro->is_new || ($ro->id == $first_id ) || 0;

                $self->set_message_edit_status($battie, $ro);
                my $children = $ro->children_count;
                my $skip = 0;
                if ($ro->title and $ro->title ne $root_title) {
                    $skip = $children;
                }
                my $node = {
                    id          => $ro,
                    children    => $children,
                    # counter: have we collected all subtrees?
                    need        => $children - $skip,
                    skip        => $skip,
                    # subtrees should appear
                    new         => $isnew || ($skip > 0),
                    rec         => [],
                };
                push @stack, $node;
                while (@stack > 0) {
                    last if $stack[-1]->{need} > 0;
                    my $last = pop @stack;
                    my $children = $last->{children};
                    my $new = $last->{new};
                    if ($new) {
                        push @folds, @{ $last->{rec} };
                    }
                    else {
                        $last->{rec} = [];
                        my $col = @stack ? $stack[-1]->{rec} : [];
                        # no leaves
                        push @$col, $last->{id} if $children;
                    }
                    if (@stack) {
                        $stack[-1]->{new} += $new;
                        $stack[-1]->{need} -= $children + 1;
                    }
                }
            }

            if (!$last_mtime or $mtime gt $last_mtime) {
                $last_mtime = $mtime;
            }
        }
        for my $fold (@folds) {
            $fold->set_old_branch(1);
        }

        $battie->timer_step("after render messages");

        if (my $user = $battie->session->get_user and $update_read) {
            $self->init_db($battie);
            eval {
                $schema->txn_do(sub {
                    my $exists = $schema->resultset('ReadMessages')->find({
                            thread_id => $thread_ro->id,
                            user_id   => $uid,
                        }, { for => 'update' });
                    unless ($exists) {
                        # new reader, reset cache for reader count
                        my $ck = "poard/thread_readers/$tid";
                        $battie->delete_cache($ck);
                        $ck = "poard/thread_header/$tid";
                        $battie->delete_cache($ck);
                    }

                    my $read = $exists;
                    if ($read) {
                    }
                    else {
                        $read = $schema->resultset('ReadMessages')->create({
                            user_id   => $user->id,
                            thread_id => $id,
                            position  => 0,
                            mtime     => DateTime->from_epoch( epoch => $last_mtime),
                        });
                    }
                    my $read_mtime = $read->mtime;
                    $read_mtime = $read_mtime->epoch if $read_mtime;
                    my $subtrees = ($thread_ro->meta || {})->{subtrees};
                    my $update = 0;
                    if ($subtrees and keys %$subtrees) {
                        my $read_subtrees = $read->meta || {};
#                        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$read_subtrees], ['read_subtrees']);
                        my $lmtime = $last_mtime;
                        if ($leaf) {
                            if ($read_subtrees->{$leaf->id} != $lmtime) {
                                $read_subtrees->{$leaf->id} = $lmtime;
                                $update = 1;
                            }
                        }
                        else {
                            my $first_id = $rendered_messages->[0]->id;
                            if ($read_subtrees->{$first_id} != $lmtime) {
                                $read_subtrees->{$first_id} = $lmtime;
                                $update = 1;
                            }
                            if ($read_mtime < $last_mtime) {
                                my $test = $read_mtime;
                                warn __PACKAGE__.':'.__LINE__.": !!! $test le $last_mtime\n";
                                $read->mtime(DateTime->from_epoch( epoch => $last_mtime));
                                $update = 1;
                            }
                        }
#                        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$read_subtrees], ['read_subtrees']);
                        $read->meta($read_subtrees);
#                        $update = 1;
                    }
#                    else {
                        if ($read_mtime < $last_mtime) {
                            $read->mtime(DateTime->from_epoch( epoch => $last_mtime));
                            $update = 1;
                        }
#                    }
                    if ($update) {
                        warn __PACKAGE__.':'.__LINE__.": update read for $uid/$tid\n";
                        $read->update;
                        my $ck = "poard/read_thread/$uid/$tid";
                        $battie->delete_cache($ck);

                        my $ro = $read->readonly;
                        $ro->set_mtime(undef);
                        $battie->to_cache($ck, $ro, 60 * 60 * 8);
                    }
                });
            };
            die "Transaction failed: $@" if $@;
        }


    }
    else {
        my $thread_cached;
        if ($view_deleted) {
            my @messages = $schema->resultset('Message')->search(
                    { thread_id => $thread_ro->id },
                    {
                        order_by => 'position',
                    }
            );
            $tids = [map { $_->id } @messages];
            $thread_cached->{msg_ids} = $tids;
            my %pos2id = map { $_->position => $_->id } @messages;
            $thread_cached->{pos2id} = \%pos2id;
        }
        else {
            $thread_cached = $battie->module_call(cache => 'from_cache', "poard/thread/$id");
            $tids = $thread_cached ? $thread_cached->{msg_ids} : undef;
            unless ($tids) {
                my @messages = $schema->resultset('Message')->search(
                        {
                            thread_id => $thread_ro->id,
                            status => {'!=' => 'deleted'},
                        },
                        {
                            order_by => 'position',
                            select => [qw/ id position /],
                        }
                );
                $tids = [map { $_->id } @messages];
                my %pos2id = map { $_->position => $_->id } @messages;
                $thread_cached->{msg_ids} = $tids;
                $thread_cached->{pos2id} = \%pos2id;
                $battie->module_call(cache => 'cache', "poard/thread/$id", $thread_cached, 60);
            }
        }
        if ($read) {
            # calculate page from position
            $page = $self->page_from_position($read, $rows, $thread_cached);
        }
        if ($page*$rows > @$tids) {
            $page = int(@$tids / $rows) + 1;
        }
        elsif ($page < 1) {
            $page = 1;
        }
        my $pager = WWW::Battie::Pager->new({
                items_pp => $rows,
                before => 3,
                after => 3,
                total_count => scalar @$tids,
                current => $page,
                link => $battie->self_url
                    . "/poard/thread/$id?p=%p"
                    ,
                title => '%p',
            })->init;
        $battie->get_data->{poard}->{pager} = $pager;
        my $user_infos = {};
        my @msg_ids = grep { $_ } @$tids[$rows*($page-1)..($rows*$page)-1];
        @$rendered_messages = $schema->resultset('Message')->search({
                id => { IN => [@msg_ids] },
            })->all;
        @$rendered_messages = map {
            my $msg = $_;
                #my $ro = $battie->module_call(cache => 'from_cache', 'poard/messages/'.$raw);
                my $id = $msg->id;
                my $cached_msgs = $self->fetch_cached_messages($battie, [$msg->id]);
                my $ro = @$cached_msgs ? $cached_msgs->[0] : undef;
                my $approved = $msg->approved_by;
                if ($approved) {
                    $user_infos->{ $approved } = undef;
                }
                if ($msg->author_id) {
                    $user_infos->{ $msg->author_id } = undef;
                }
                unless ($ro) {
#                    $ro = $self->render_message($battie, $msg, 'html', 0, 1);
                    $ro = $self->message_to_cache($battie, $msg, 'add');
                }
                else {
                    $self->set_message_edit_status($battie, $ro);
                    if ($msg->author_id) {
                        $user_infos->{ $msg->author_id } = undef;
                    }
                }
                $ro->set_thread($thread_ro);
                $ro
        } @$rendered_messages;
        if (keys %$user_infos) {
            $self->fetch_user_infos($battie, $user_infos);
        }
        for my $msg (@$rendered_messages) {
            my $uid = $msg->author_id;
            if ($uid) {
                $self->msg_author($msg, $user_infos->{ $uid });
            }
            my $approved = $msg->approved_by;
            if ($approved) {
                $msg->set_approved_by($user_infos->{ $approved });
            }
        }
        if (my $user = $battie->session->get_user) {
            $self->init_db($battie);
            if (@$rendered_messages) {
                my $last_pos = $rendered_messages->[-1]->position;
                eval {
                    $schema->txn_do(sub {
                        my $exists = $schema->resultset('ReadMessages')->find({
                                thread_id => $thread_ro->id,
                                user_id   => $user->id,
                            }, { for => 'update' });
                        unless ($exists) {
                            # new reader, reset cache for reader count
                            my $ck = "poard/thread_readers/$tid";
                            $battie->delete_cache($ck);
                            $ck = "poard/thread_header/$tid";
                            $battie->delete_cache($ck);
                        }
                        my $read = $exists;
                        # TODO $last_pos
                        if ($read and $last_pos) {
                            my $read_mtime = $read->mtime;
                            $read_mtime = $read_mtime->epoch if $read_mtime;
                            if ($read->position < $last_pos or $read_mtime < $last_mtime) {
                                $read->position($last_pos);
                                $read->mtime(DateTime->from_epoch( epoch => $last_mtime ));
                                $read->update;
                                my $ck = "poard/read_thread/$uid/$tid";
                                $battie->delete_cache($ck);
                            }
                        }
                        # TODO $last_pos
                        elsif ($last_pos) {
                            $read = $schema->resultset('ReadMessages')->create({
                                    user_id   => $user->id,
                                    thread_id => $id,
                                    position  => $last_pos,
                                    mtime     => DateTime->from_epoch( epoch => $last_mtime ),
                            });
                        }
                    });
                };
                die "Transaction failed: $@" if $@;
            }
        }
    }
    $thread_ro->set_messages($rendered_messages);

    # readers
    {
        my $ck = "poard/thread_readers/$id";
        my $count_ref = $battie->from_cache($ck);
        unless ($count_ref) {
            my $count = $schema->resultset('ReadMessages')->count({
                    thread_id => $thread_ro->id,
                });
            $count_ref = \$count;
            $battie->to_cache($ck, $count_ref, 60 * 60 * 24 * 30);
        }
        $thread_ro->set_readers($$count_ref);
    }

    if ($thread_ro->is_survey) {
        my $surveys = $self->render_survey($battie, $thread_ro);
        $thread_ro->set_surveys($surveys);
    }
    return ($thread_ro, undef, $page);
}

sub fetch_user_infos {
    my ($self, $battie, $user_infos) = @_;
    for my $uid (keys %$user_infos) {
        my $user_ro = $battie->from_cache('poard/user_info/' . $uid) or next;
        $user_infos->{ $uid } = $user_ro;
    }
    my @left = grep { ! $user_infos->{ $_ } } keys %$user_infos;
    if (@left) {
        warn __PACKAGE__.':'.__LINE__.": CACHE USER INFOS (@left)\n";
        $self->init_db($battie);
        my $uschema = $self->schema->{user};
        my $groups = $battie->allow->get_groups;
        my $search = $uschema->resultset('User')->search(
            { id => [@left] },
            {
                prefetch => [qw/ profile settings /],
                'select' => [qw/ me.id me.group_id me.nick me.ctime profile.homepage profile.avatar profile.signature settings.messagecount /],
            });
        while (my $user = $search->next) {
            my $uid = $user->id;
            my $user_ro = $self->render_author($battie, $user, 'html');
            $user_ro->set_groupname($groups->{ $user_ro->group_id }->[0]) if $user_ro->group_id;
            $user_ro->set_ctime_epoch($user_ro->ctime->epoch);
            $user_ro->set_ctime(undef);
            $user_infos->{ $uid } = $user_ro;
            $battie->to_cache("poard/user_info/$uid", $user_ro, 60 * 60 * 24 * 30);
        }
    }
}


=pod

sub fetch_msg_authors {
    my ($self, $battie, $msgs) = @_;
    my $uschema = $self->schema->{user};
    my %uids = map {
        $_->author_id ? ($_->author_id => 1) : ()
    } @$msgs;

    my %users;
    if (keys %uids) {
        my $search = $uschema->resultset('User')->search(
            { id => [keys %uids] },
            {
                prefetch => [qw/ profile settings /],
                #'select' => [qw/ me.id me.nick me.ctime profile.homepage profile.avatar profile.signature /],
            });
        while (my $user = $search->next) {
            $users{ $user->id } = $user;
        }
    }

    for my $msg (@$msgs) {
        next unless $msg->author_id;

        my $user = $users{ $msg->author_id };
        next unless $user;
        $self->render_msg_author($battie, $msg, $user, 'html');
    }
}

=cut

sub page_from_position {
    my ($self, $pos, $rows, $info) = @_;
    #warn __PACKAGE__." page_from_position(@_)\n";
    my $pos2id = $info->{pos2id};
    my %id2pos = reverse %$pos2id;
    my $id = $pos2id->{$pos};
    my @ids = @{ $info->{msg_ids} || [] };
    my $step = 0;
    my $found;
    while (not defined $found) {
        my @slice = grep { $_ } @ids[$step*$rows .. $step*$rows+$rows-1];
        last unless @slice;
        #warn __PACKAGE__.':'.__LINE__.": \$id2pos{ $slice[-1] }=$id2pos{ $slice[-1] } | $pos step=$step\n";
        if ($id2pos{ $slice[-1] } > $pos) {
            $found = $step;
            last;
        }
        elsif ($id2pos{ $slice[-1] } >= $pos) {
            $found = $step;
        }
        $step++;
    }
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$found], ['found']);
    return ($found+1) || 1;
}

sub poard__thread_mini {
    my ($self, $battie) = @_;
    $battie->response->set_needs_navi(0);
    my $request = $battie->request;
    my $data = $battie->get_data;
#    if ($request->param('is_ajax')) {
        $data->{main_template} = "poard/ajax.html";
#    }
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my ($id, $leaf) = @$args;
    my ($thread_ro, $thread, $page) = $self->view_thread($battie,
        id          => $id,
        delete      => 0,
        leaf        => $leaf,
        update_read => 0,
        full        => 0,
    );
    $data->{poard}->{thread} = $thread_ro;
}

sub poard__view_thread {
    shift->poard__thread(@_);
}
sub poard__thread {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my ($id, $leaf) = @$args;
    my $can_delete = $battie->get_allow->can_do(poard => 'mod_delete_thread');
    my ($thread_ro, undef, $page) = $self->view_thread($battie,
        id          => $id,
        delete      => $can_delete ? 'delete' : 0,
        leaf        => $leaf,
        update_read => 1,
        full        => 1,
    );
    $battie->timer_step("after view_thread");
    $self->init_seo($battie, $thread_ro->board);
    my $data = $battie->get_data;
    $data->{poard}->{board} = $thread_ro->board;
    $data->{poard}->{thread} = $thread_ro;
    my ($title, @crumbs);
    if ($thread_ro->is_tree) {
        $data->{poard}->{last_levels} = [(1) x ($thread_ro->messages->[-1]->level+1)];
        if ($leaf) {
            my $first = $thread_ro->messages->[0];
            if (not defined $first->title) {
                $battie->response->set_no_index(1);
                $battie->response->set_no_archive(1);
            }
            my @previous = grep { defined $_->title } @{ $self->parents_to_msg($battie, $schema, $first->id) };
            shift @previous;
            $title = $first->title;
            @crumbs = [$thread_ro->title, "poard/thread/$id"];
            push @crumbs, map {
                [$_->title, "poard/thread/$id/" . $_->id],
            } reverse @previous;
        }
        else {
            $title = $thread_ro->title;
        }
    }
    else {
        $title = $thread_ro->title;
    }
    if ($battie->get_session->userid) {
        # we are logged in, see if we have subscribed to this thread
        my $notify = $schema->resultset('Notify')->search({
                user_id => $battie->session->userid,
                thread_id => $id,
            }, { select => [qw/ thread_id /] })->single;
        if ($notify) {
            $data->{poard}->{subscribed} = 1;
        }
    }
    $battie->response->set_last_modified($thread_ro->get_mtime_epoch || $thread_ro->get_mtime);
    if (not $thread_ro->is_tree and $page > 1) {
        $title .= ' (' . $battie->translate("global_pages", 1) . " $page)";
    }
    if ($battie->get_session->userid and $battie->get_session->userid == $thread_ro->author_id) {
        $thread_ro->set_own(1);
    }
    my $board = $thread_ro->board;
    $self->make_board_breadcrumb($battie, $board);
    for my $crumb (@crumbs) {
        $battie->crumbs->append(@$crumb);
    }
    $data->{poard}->{title} = $title;
    if ($thread_ro->solved) {
        $title .= ' (' . $battie->translate('poard_solved') . ')';
    }
    $data->{subtitle} = $self->make_subtitle(thread =>
        board  => $thread_ro->board->name,
        thread => $title,
    );
    my $can_solve = $self->is_solvable($battie, $thread_ro);
    $data->{poard}->{thread_solvable} = $can_solve;
    my $tags = $thread_ro->get_tags || [];
    if (@$tags) {
        my $keywords = $battie->response->get_keywords;
        $battie->response->set_keywords("$keywords, " . join ",", map { $_->get_name } @$tags);
    }
}

sub parents_to_board {
    my ($self, $battie, $schema, $from_cache, $board) = @_;
    my $id = ref $board ? $board->id : $board;
    if ($from_cache) {
        my $boards = $self->fetch_boards($battie);
        my $parents;
        my $board = $boards->{ $id };
        my $parent_ids = $board->parent_ids;
        for my $id (@$parent_ids) {
            push @$parents, $boards->{ $id };
        }
        return $parents;
    }
#    my $parents = $battie->from_cache("poard/parents/$id");
#    unless ($parents) {
        unless (ref $board) {
            $board = $schema->resultset('Board')->find($board);
        }
        return unless $board;
        my @parents = map { $_->readonly } $schema->resultset('Board')->parents($board)->all;
        my $parents = \@parents;
#        $battie->to_cache("poard/parents/$id", $parents, 60 * 60);
#    }
#    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$parents], ['parents']);
    return $parents;
}

sub parents_to_msg {
    my ($self, $battie, $schema, $msid) = @_;
    my $object = ref $msid ? $msid : $schema->resultset('Message')->find($msid);
    my @parents = $schema->resultset('Message')->parents($object)->all;
    return [ $object, reverse @parents ];
}

sub poard__subscribe_thread {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my ($id, $msid) = @$args;
    my $user_id = $battie->get_session->userid or return;
    my $submit = $request->get_submit;
    my $thread = $self->check_existance($battie, Thread => $id);
    $self->check_visibility($battie, $thread);
    if ($msid) {
        my $message = $schema->resultset('Message')->find($msid);
        if (!$message or $message->thread_id != $id) {
            $msid = 0;
        }
    }
    my $data = $battie->get_data;
    if ($submit->{subscribe} and not $battie->valid_token) {
        delete $submit->{subscribe};
        $data->{poard}->{error}->{token} = 1;
    }
    if ($submit->{unsubscribe} and not $battie->valid_token) {
        delete $submit->{unsubscribe};
        $data->{poard}->{error}->{token} = 1;
    }
    if ($submit->{subscribe} or $submit->{unsubscribe}) {
        my $notify = $schema->resultset('Notify')->find({
                user_id   => $user_id,
                thread_id => $id,
            });
        if ($submit->{subscribe}) {
            unless ($notify) {
                my $notify = $schema->resultset('Notify')->create({
                        user_id       => $user_id,
                        thread_id     => $id,
                        ctime         => undef,
                        last_notified => undef,
                        $msid ? (msg_id => $msid) : (),
                    });
            }
            $data->{poard}->{subscribed} = 1;
        }
        else {
            if ($notify) {
                $notify->delete;
            }
            $data->{poard}->{subscribed} = 0;
        }
        $battie->writelog($thread, ($submit->{subscribe} ? '' : 'un') . 'subscribe');
        $battie->delete_cache("poard/subscription_ids/$user_id");
        if ($request->param('is_ajax')) {
            $data->{main_template} = "poard/ajax.html";
        }
        else {
            $battie->set_local_redirect("/poard/thread/$id");
        }
        return;
    }
}

sub render_survey {
    my ($self, $battie, $thread_ro) = @_;
    my $schema = $self->schema->{poard};
    my $id = $thread_ro->id;
    my $ck = "poard/thread_surveys/$id";
    my $rendered = $battie->from_cache($ck);
    my %voted;
    unless ($rendered) {
        my $fields = [qw/ id question votecount is_multiple status /];
        my @surveys = $schema->resultset('Survey')->search({
                thread_id => $id,
            }, {
                select => $fields,
            })->all;
        my @rendered;
        for my $s (@surveys) {
            my $ro = $s->readonly($fields);
            my $count = $s->votecount;
            $voted{ $s->id } = 0;
            my $total = 0;
            my @options = map {
                my $ro = $_->readonly([qw/ id answer votecount position /]);
                $total += $_->votecount;
                $ro->set_percent($count ? int(($_->votecount / $count)*100) : 0);
                $ro
            } $s->search_related('options', {}, {
                select => [qw/ id answer votecount position /],
            });
            $ro->set_total_votecount($total);
            $ro->set_options(\@options);
            push @rendered, $ro;
        }
        $rendered = \@rendered;
        $battie->to_cache($ck, $rendered, 60 * 60 * 24 * 30);
    }
    else {
        for my $survey (@$rendered) {
            $voted{ $survey->id } = 0;
        }
    }

    if ($battie->get_session->userid) {
        my $search = $schema->resultset('SurveyVote')->search({
                survey_id   => { IN => [keys %voted] },
                user_id     => $battie->get_session->userid,
            }, { select => [qw/ survey_id /] });
        while (my $item = $search->next) {
            $voted{ $item->survey_id }++;
        }
        for my $survey (@$rendered) {
            $survey->set_has_voted($voted{ $survey->id });
        }
    }

    return $rendered;
}

sub poard__view_board {
    shift->poard__board(@_);
}
sub poard__board {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $self->init_db($battie);
    my $args = $request->get_args;
    my $schema = $self->schema->{poard};
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    if ($id =~ tr/0-9//c) {
        $battie->not_found_exception("Board '$id' does not exist");
    }
    my $page = $request->pagenum(10_000); # not more than 10000 pages;
    my $rows = $self->get_rows->{board};

    my $ck = "poard/board_info/$id";
    my $board_info = $battie->from_cache($ck);
    my ($board_ro, $board_count);
    if ($board_info) {
        ($board_ro, $board_count) = ($board_info->{board}, $board_info->{count});
    }
    else {
        my $board = $schema->resultset('Board')->find($id)
            or $self->exception("Argument", "Board '$id' does not exist");
        $board_count = $schema->resultset('Thread')->search({
                board_id => $board->id,
                status => { '!=' => 'deleted' },
            })->count;
        $board_ro = $board->readonly;
        $board_info = {
            board => $board_ro,
            count => $board_count,
        };
        $battie->to_cache($ck, $board_info, 60 * 60 * 5);
    }
    $battie->not_found_exception("Board '$id' is not visible by you", [])
        unless $self->check_board_group($battie, $board_ro);
    my @threads;
    my $data = $battie->get_data;
    my @rel_threads = $schema->resultset('Thread')->search({
            board_id => $board_ro->id,
            status => { '!=' => 'deleted' },
        },
        {
            order_by => 'fixed desc, mtime desc',
            rows => $rows,
            page => $page,
        });
    my $pager = WWW::Battie::Pager->new({
            items_pp => $rows,
            total_count => $board_count,
            before => 3,
            after => 3,
            current => $page,
            link => $battie->self_url
                . "/poard/board/$id?p=%p"
                ,
            title => '%p',
        })->init;
    $data->{poard}->{pager} = $pager;
    my %user_ids;
    my @msgs;
    my %readers;
    my %to_cache;
    my @unfinished_threads;
    my @cache_keys;
    for my $thread (@rel_threads) {
        my $tid = $thread->id;
        my $ck = "poard/thread_header/$tid";
        push @cache_keys, $ck;
    }
    # TODO bugfix when there is only 1 thread
    my $cached_threads = $battie->from_cache(@cache_keys);
    for my $thread (@rel_threads) {
        my $tid = $thread->id;
        my $ck = "poard/thread_header/$tid";

        #my $cached_thread = $battie->from_cache($ck);
        my $cached_thread = $cached_threads->{$ck};
        if ($cached_thread) {
            push @threads, $cached_thread;
            next;
        }
        $readers{ $tid } = 0;
        my $author_id = $thread->author_id;
        $user_ids{ $author_id }++ if $author_id;
        my $thread_ro = $thread->readonly;
        $self->render_subtrees($thread_ro) if ($thread->is_tree);
        my $last_ro = $self->render_last_message($battie, $thread, 'none', 0);
        if ($last_ro) {
            my $last_ctime = $last_ro->ctime;
            if ($thread_ro->mtime == $last_ctime) {
                $thread_ro->set_mtime(undef);
            }
            $thread_ro->set_last($last_ro);
            if (my $author_id = $last_ro->author_id) {
                push @msgs, $last_ro;
                $user_ids{ $author_id } = 0;
            }
        }
        else {
            if ($thread_ro->ctime == $thread_ro->mtime) {
                $thread_ro->set_mtime(undef);
            }
        }
        if (my $author_id = $thread->author_id) {
            $user_ids{ $author_id } = 0;
            push @msgs, $thread_ro;
        }
        push @threads, $thread_ro;
        push @unfinished_threads, $thread_ro;
    }
    if (keys %readers) {
        $self->_fetch_thread_readers($battie, $schema, \%readers);
    }

    if (keys %user_ids) {
        $self->fetch_user_infos($battie, \%user_ids);
        my $users = $battie->module_call(login => 'get_user_by_id', [grep { ! $user_ids{$_} } keys %user_ids]);
        for my $user (@$users) {
            $user_ids{$user->id} = $user->readonly([qw/ nick id /]);
        }
    }
    for my $user (values %user_ids) {
        next unless $user;
        $user->set_profile(undef);
        $user->set_settings(undef);
        $user->set_ctime(undef);
    }
    for my $thread (@unfinished_threads) {
        my $tid = $thread->id;
        my $readers = $thread->readers;
        $thread->set_readers($readers{ $thread->get_id });
        my $author_id = $thread->author_id or next;
        my $user = $user_ids{ $author_id };
        $thread->set_author($user);
    }
    for my $msg (@msgs) {
        my $user = $user_ids{ $msg->author_id };
        $msg->set_author($user);
    }
    for my $thread (@unfinished_threads) {
        my $tid = $thread->id;
        my $ck = "poard/thread_header/$tid";
        my $readers = $thread->readers;
        $battie->to_cache($ck, $thread, time + CACHE_THREAD_HEADER);
    }
    $self->mark_read_threads($battie, \@threads);

    my $top_tags = {};
    {
        my $ck = 'poard/top_tags/board_' . $board_ro->id;
        $top_tags = $battie->from_cache($ck);
        unless ($top_tags) {
            $top_tags->{time} = time;
            my $search = $schema->resultset('ThreadTag')->search({
                    'board.id' => $id,
                },
                {
                    join => [{ thread => 'board' }, 'tag'],
                    group_by => 'me.tag_id',
                    select => ['me.tag_id', 'tag.id', 'tag.name', { count => 'me.tag_id' }],
                    as => ['tag_id', 'id', 'name', 'tag_count' ],
                    order_by => \'COUNT(me.tag_id) desc, tag.name',
                    # does not work
                    # order_by => 'tag_count desc',
                    rows => 20,
                });
            while (my $thread_tag = $search->next) {
                my $tag = $thread_tag->tag;
                my $name = $tag->name;
                my $count = $thread_tag->get_column('tag_count');
                push @{ $top_tags->{tags} }, {
                    tag => $tag->readonly,
                    count => $count,
                };
            }
            $battie->to_cache($ck, $top_tags, 60 * 60 * 12);
        }
    }
    $data->{poard}->{board} = $board_ro;
    $data->{poard}->{threads} = \@threads;
    $data->{poard}->{top_tags} = $top_tags;
    $data->{subtitle} = $self->make_subtitle(board =>
        board  => $board_ro->name,
    );
    $self->make_board_breadcrumb($battie, $board_ro);
}

sub render_last_message {
    my ($self, $battie, $thread, $type, $with_author) = @_;
    my $last = $thread->search_related('messages',
        {
            position => { '>' , 0 },
            status => 'active',
        }, {
            order_by => 'position desc',
            rows => 1,
            select => [qw/ id ctime mtime author_id author_name /],
        })->single;
    if ($last) {
        my $last_ro = $last->readonly([qw/ id ctime mtime author_id /]);
        return $last_ro;
    }
    return;
}

sub fetch_board_tags {
    my ($self, $battie, $board, $type) = @_;
    my $meta = $board->meta || {};
    my $string = $meta->{tags}->{ $type };
    my @ids = split /,/, $string;
    my $tags = [];
    my $schema = $self->schema->{poard};
    for my $id (@ids) {
        my $tag = $schema->resultset('Tag')->find($id) or next;
        my $ro = $tag->readonly;
        push @$tags, $ro;
    }
    return $tags;
}

sub thread_default_tags {
    my ($self, $battie, $board) = @_;
    my $schema = $self->schema->{poard};
    my $tags_default = $self->fetch_board_tags( $battie, $board, 'default' );
    my $tags_example = $self->fetch_board_tags( $battie, $board, 'example' );
    my $tags_user = [];
    my $uid = $battie->get_session->userid;
    if ($uid) {
        my @user_tags = map { $_->tag } $schema->resultset('UserTag')->search({
                user_id => $uid,
            }, {
                order_by => 'ctime desc',
                join => 'tag',
            })->all;
        $tags_user = [map { $_->readonly } @user_tags];
    }
    return ($tags_default, $tags_example, $tags_user);
}

sub poard__create_thread {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $response = $battie->response;
    $response->set_no_cache(1);
    $self->init_db($battie);
    my $args = $request->get_args;
    my $thread;
    my $thread_ro;
    my $message_ro;
    my $schema = $self->schema->{poard};
    my ($board_id) = @$args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my $board = $schema->resultset('Board')->find($board_id);
    my $data = $battie->get_data;
    if ($self->get_post_hint) {
        $data->{poard}->{post_hint} = 1;
    }
    $data->{poard}->{create_thread} = 1;
    $self->exception("Argument", "Board '$board_id' does not exist") unless $board;
    $self->exception("Argument", "Board '$board_id' is a superboard") if $board->lft == 1;
    $self->exception("Argument", "Board '$board_id' is a superboard") unless $board->is_leaf;
    # TODO
    #$self->check_visibility($battie, $thread);
    $battie->not_found_exception("Board '$board_id' is not visible by you", [])
        unless $self->check_board_group($battie, $board);
    my $can_post = $battie->get_allow->can_do(poard => 'post_answer_authorized');
    my $from_form = $request->param('form');
    my $correct_bbcode = $request->param('correct_bbcode');
    my $correct_urls = $request->param('correct_urls');
    my $author_name = $request->param('message.author_name');
    my $title = $request->param('thread.title');
    my $text = $request->param('message.message');
    my $subscribe = $request->param('subscribe');
    $data->{poard}->{subscribe} = defined $title
        ? $subscribe
        : $data->{settings}->{poard}->{edit}->{subscribe};
    my $tags = [];
    my ($tags_default, $tags_example, $tags_user) = $self->thread_default_tags($battie, $board);
    $data->{poard}->{tags_example} = $tags_example;
    $data->{poard}->{tags_default} = $tags_default;
    $data->{poard}->{tags_user} = $tags_user;
    my $conf = $self->get_attachment;
    $data->{poard}->{attachment_conf} = $conf;

    if ($submit->{attach}) {
        $submit->{preview} = delete $submit->{attach};
    }
    if ($submit->{preview} or $submit->{save}) {
        my $result = $self->_check_message($battie, $text, {
                links => $correct_urls,
                bbcode => $correct_bbcode,
            });
        my $error = $result->{error};
        if (@$error) {
            $text = $result->{text};
            for my $e (@$error) {
                $data->{poard}->{error}->{message}->{$e} = 1;
            }
        }
        if (@$error and $submit->{save}) {
            $submit->{preview} = delete $submit->{save};
        }
        if ($submit->{save}) {
            $text = $result->{text};
        }
    }

    $data->{poard}->{antispam} = $self->get_antispam;
    if ($submit->{save}) {
        if ($self->get_antispam and not $request->param('antispam_ok')) {
            delete $submit->{save};
            $submit->{preview} = 1;
        }
    }
    if ($submit->{save}) {
        if (!$battie->session->userid and (not defined $author_name or not length $author_name)) {
            # we have a guest, so we need a name
            $submit->{preview} = delete $submit->{save};
            $data->{poard}->{error}->{no_name} = 1;
        }
        elsif (not $battie->valid_token) {
            $data->{poard}->{error}->{token} = 1;
            $submit->{preview} = delete $submit->{save};
        }
        elsif (not defined $title or not length $title or $title !~ tr/ //c) {
            $data->{poard}->{error}->{no_title} = 1;
            $submit->{preview} = delete $submit->{save};
        }
        elsif (not defined $text or $text !~ m/\S/) {
            $data->{poard}->{error}->{no_text} = 1;
            $submit->{preview} = delete $submit->{save};
        }
        elsif (length $text > 10_000) {
            $data->{poard}->{error}->{long_text} = 1;
            $submit->{preview} = delete $submit->{save};
        }
        elsif (!$can_post) {
            # first check how many unapproved threads we have in the board
            my $max = $self->get_max_unapproved_threads || 0;
            if ($max) {
                my $count = $schema->resultset('Thread')->count(
                    {
                        board_id => $board_id,
                        status => 'onhold',
                    }
                );
                if ($count >= $max) {
                    $data->{poard}->{error}->{max_unapproved_threads} = 1;
                    $submit->{preview} = delete $submit->{save};
                }
            }
        }
        unless ($can_post) {
            # guest or new user
            my $is_spam = $battie->spamcheck(
                $self->get_antispam,
                text => $text,
                defined $author_name ? (author => $author_name) : (),
            );
            if ($is_spam) {
                $battie->log_spam(
                    text => $text,
                    type => "thread",
                );
                delete $submit->{save};
                $submit->{preview} = 1;
                $data->{poard}->{error}->{spam} = 1;
            }
        }

    }
    if ($submit->{preview} or $submit->{save}) {
        my $plus = $submit->{save} ? 0 : 3;
        unless ($request->param('tags')) {
            push @$tags, @$tags_default;
        }
        my $result = $self->fetch_tags_from_form($battie, {
                tags => $tags,
                plus => $plus,
                prefix => ['tag', 'tag_new_user','tag_new_example'],
            });
    }
    $data->{poard}->{use_tags} = $tags;

    my $attachments = [];
    my $attachment_errors = [];
    if ($submit->{preview} or $submit->{save}) {
        my $save = 0;
        if ($submit->{save}) {
            $save = 1;
        }
        if ($battie->get_allow->can_do(poard => 'message_attach')) {
            ($attachments, $attachment_errors)
                = $self->fetch_attachments_from_form($battie, $save);
            $data->{poard}->{attachments} = $attachments;
            if (@$attachment_errors) {
                delete $submit->{save};
                $submit->{preview} = 1;
                $data->{poard}->{error}->{attachment} = $attachment_errors;
            }
        }
    }

    if ($submit->{preview} or $submit->{__default} or $submit->{save}) {
        $self->exception("Argument", "Not enough arguments") unless $board_id;
        if ($submit->{save}) {
            $text =~ s/^\s*(.*?)\s*\z/$1/s;
            $schema->txn_begin;
            my $message;
            eval {
                $thread = $schema->resultset('Thread')->create({
                        board_id => $board_id,
                        author_id => $battie->get_session->userid || 0,
                        title => $title,
                        ctime => undef,
                        messagecount => 0,
                        status => $can_post ? 'active' : 'onhold',
                        $can_post ? () : (author_name => $author_name),
                        is_tree => 1,
                    });
                $message = $schema->resultset('Message')->insert_new(0, {
                        message => $text,
                        thread_id => $thread->id,
                        ctime => undef,
                        author_id => $battie->get_session->userid || 0,
                        status => $can_post ? 'active' : 'onhold',
                        $can_post ? () : (author_name => $author_name),
                        (scalar @$attachments) ? ( has_attachment => 1 ) : (),
                    });
                # tags
                if (@$tags) {
                    $self->insert_thread_tags($battie, $thread, $tags);
                }
                # attachments
                if (@$attachments) {
                    $self->add_attachments($battie, $message, $attachments);
                }

                $self->message_to_cache($battie, $message, 'set');
                $self->update_user_settings($battie, $message->author_id);
                if ($can_post) {
                    $self->update_search_index($battie, update => thread => $thread->id);
                }
                if ($subscribe) {
                    my $notify = $schema->resultset('Notify')->create({
                            user_id       => $battie->get_session->userid,
                            thread_id     => $thread->id,
                            ctime         => undef,
                            last_notified => undef,
                        });
                        $battie->delete_cache("poard/subscription_ids/" . $battie->get_session->userid);
                }
                $self->delete_latest_cache($battie, $thread->board);
            };
            if ($@) {
                warn __PACKAGE__.':'.__LINE__.": TRANSACTION FAILED: $@\n";
                $schema->txn_rollback;
                $self->exception("SQL", "Could not create thread");
            }
            else {
                unless ($can_post) {
                    $battie->delete_cache('poard/onhold');
                }
                my $thread_id = $thread->id;
                $battie->writelog($thread);
                $battie->writelog($message);
                $schema->txn_commit;
                if ($can_post) {
                    $battie->set_local_redirect("/poard/thread/$thread_id");
                }
                else {
                    $battie->set_local_redirect("/poard/create_thread/$board_id?confirmation=1;thread_id=$thread_id");
                }
            }
            return;
        }
        elsif ($submit->{preview} or $submit->{__default}) {
            $response->set_no_cache(0); # otherwise textarea will be emptied
            $thread_ro = WWW::Poard::Model::Thread::Readonly->new({
                    board_id => $board_id,
                    title => $title,
                    status => $can_post ? 'active' : 'onhold',
                    $can_post ? () : (author_name => $author_name),
                });
            $message_ro = WWW::Poard::Model::Message::Readonly->new({
                    message => $text,
                    status => $can_post ? 'active' : 'onhold',
                    $can_post ? () : (author_name => $author_name),
                });
            my $re = $battie->get_render->render_message_html($message_ro->message);
            $message_ro->set_rendered($re);
            $data->{poard}->{message} = $message_ro;
        }
    }
    elsif ($request->param('confirmation')) {
        $data->{poard}->{confirmation} = 1;
        $data->{poard}->{thread_id} = $request->param('thread_id');
    }
    $data->{poard}->{correct_bbcode} = $from_form ? $correct_bbcode : 1;
    $data->{poard}->{correct_urls} = $from_form ? $correct_urls : 1;
    my $board_ro = $board->readonly;
    $data->{poard}->{board} = $board_ro;
    $data->{poard}->{thread} = $thread_ro;
    $data->{poard}->{message} = $message_ro;
    $data->{subtitle} = "Create Thread in Board " . $board_ro->name;
    $self->make_board_breadcrumb($battie, $board);
}

sub add_attachments {
    my ($self, $battie, $message, $attachments, $args) = @_;
    my $schema = $self->schema->{poard};
    my $conf = $self->get_attachment;
    my $attach_id = $args->{max_id} || 0;
    my $attach_dir = $conf->{path};
    my $thumb_dir = $conf->{thumbdir};
    $thumb_dir = File::Spec->catfile($battie->get_paths->{docroot}, $thumb_dir);
    if (-d $attach_dir and -w $attach_dir) {
        for my $attach (@$attachments) {
            my $fullpath = $attach->{fullpath};
            $attach_id++;
            my $thumbfile = $attach->{thumbfile};
            my $msg_attach = $schema->resultset('Attachment')->create({
                    message_id  => $message->id,
                    attach_id   => $attach_id,
                    type        => $attach->{type},
                    filename    => $attach->{filename},
                    size        => $attach->{size},
                    deleted     => 0,
                    meta        => $attach->{meta},
                    thumb       => $thumbfile ? 1 : 0,
                });
            my $attach_id = $msg_attach->attach_id;
            my $msid = $message->id;
            my $dirs = join '/', $msid =~ m/(\d{1,3})/g;
            my $target = "$attach_dir/$dirs";
            mkpath($target);
            move($fullpath, "$target/$attach_id") or die $!;
            if ($thumbfile) {
                my $target = "$thumb_dir/$dirs";
                mkpath($target);
                my (undef, $itype) = split m{/}, $attach->{type};
                move($thumbfile, "$target/thumb_$attach_id.$itype") or die $!;
            }
        }
    }
}


sub fetch_attachments_from_form {
    my ($self, $battie, $save, $args) = @_;
    $save ||= 0;
    my $request = $battie->request;
    my @uploads;
    my $now = time;
    my $conf = $self->get_attachment;
    my $tmpdir = $conf->{tmpdir};
    my $thumbdir = $conf->{thumbdir};
    my $max_num = $conf->{max};
    my @tmp_keys = $save == 2 ? () : grep { m/^attach\.tmp\.id\.\d+\z/ } $request->param();
    my $filenames = $args->{filenames};

    my $flm = File::LibMagic->new();
    my $num_uploads = $args->{num} || 0;
    my $total_size = $args->{total_size} || 0;
    my @errors;
    my $uid = $battie->get_session->userid;
    for my $key (@tmp_keys) {
        my ($num) = $key =~ m/^attach\.tmp\.id\.(\d+)\z/;
        my $id = $request->param($key);
        if ($id =~ m/^(\d{9,11})-([a-zA-Z0-9]{5})\z/) {
            $id = $1;
            my $id2 = $2;
            my $select = $request->param("attach.tmp.select.$num");

            my $file = "$tmpdir/poard_attach_uid${uid}_${id}_${id2}";
            unless (-f $file) {
                next;
            }
            unless ($select) {
                # checkbox was unchecked, delete tmpfile
                unlink $file;
                next;
            }
            # update mtime so that tmpfile won't get deleted
            utime $now, $now, $file;
            my $size = -s $file;
            my $filename = $request->param("attach.tmp.filename.$num");
            $filename = substr($filename, 0, 32) if length($filename) > 32;
            my $create_thumb = $request->param("attach.tmp.thumb.$num") ? 1 : 0;
            if ($filenames->{$filename}) {
                push @errors, 'dup_filename';
                next;
            }
            if (not defined $filename) {
                $filename = "attach.dat";
            }
            elsif ($filename !~ m/^[\w-][\w.-]*\z/) {
                $filename = "attach.dat";
            }
            $filenames->{$filename}++;
            $total_size += $size;
            push @uploads, {
                id => "$id-$id2",
                size => $size,
                filename => $filename,
                new => 0,
                thumb => $create_thumb,
                $save ? (fullpath => $file) : (),
            };
        }
        else {
            next;
        }
        last if ($num_uploads + @uploads) >= $max_num;
    }
    # uploads
    my $upload = $request->get_cgi->upload("attach.new");
    if ($upload) {
        UPLOAD: {
            if (($num_uploads + @uploads) >= $max_num) {
                push @errors, 'max';
                last UPLOAD;
            }
            my $create_thumb = $request->param('attach.create_thumb') ? 1 : 0;
            my $suffix = '';
            my $filename = "$upload";
            if ($filename =~ s/(\.[a-zA-Z0-9]{1,5})\z//) {
                $suffix = $1;
            }
            my $maxlength = 32 - length($suffix);
            # some browsers like IE submit the full path of the file
            my @paths = split m#[\\/]#, $filename;
            $filename = pop @paths;
            $filename =~ s/^.*?([\w-][\w.-]*).*/$1/;
            $filename = substr($filename, 0, $maxlength) if length($filename) > $maxlength;
            $filename .= $suffix;
            if ($filenames->{$filename}) {
                push @errors, 'dup_filename';
                last UPLOAD;
            }
            my $id = $now;
            my $tfh = File::Temp->new(
                TEMPLATE    => "poard_attach_uid${uid}_${id}_XXXXX",
                DIR         => $tmpdir,
                UNLINK      => 0,
            );
            my $tfile = $tfh->filename;
            {
                local $/ = \4096;
                while (my $chunk = <$upload>) {
                    print $tfh $chunk;
                }
            }
            close $tfh;
            my $size = -s $tfile;
            if ($size > $conf->{max_size}) {
                unlink $tfile;
                push @errors, 'max_size';
                last UPLOAD;
            }
            $total_size += $size;
            if ($total_size > $conf->{max_totalsize}) {
                unlink $tfile;
                push @errors, 'max_totalsize';
                last UPLOAD;
            }
            my $mt = $self->fetch_mimetype($flm, $tfile, $suffix);
            if (not $mt or not $conf->{types}->{$mt}) {
                warn __PACKAGE__.':'.__LINE__.": unknown $mt\n";
                unlink $tfile;
                push @errors, 'mimetype';
                last UPLOAD;
            }
            my ($id2) = $tfile =~ m/(\w{5})\z/;
            push @uploads, {
                suffix => $suffix,
                mimetype => $mt,
                id => "${id}-${id2}",
                filename => $filename,
                size => $size,
                new => 1,
                thumb => $create_thumb,
                $save ? (fullpath => $tfile) : (),
            };
        }
    }
    if ($save) {
        for my $upload (@uploads) {
            my $tfile = $upload->{fullpath};
            my $mt = $upload->{mimetype};
            my $suffix = $upload->{suffix};
            unless ($suffix) {
                ($suffix) = $upload->{filename} =~ m/(\.[a-zA-Z_]+)\z/;
            }
            unless ($mt) {
                $mt = $self->fetch_mimetype($flm, $tfile, $suffix);
            }
            $mt ||= 'unknown';
            $upload->{type} = $mt;
            my $meta = {};
            $upload->{meta} = $meta;
            open my $fh, '<', $tfile or die $!;
            if ($mt =~ m{^image/(jpeg|gif|png)\z}) {
                my $itype = $1;
                my $resize = Image::Resize->new($tfile);
                if ($resize) {
                    my ($x, $y) = ($resize->width, $resize->height);
                    $meta->{width} = $x;
                    $meta->{height} = $y;
                    if ($upload->{thumb}) {
                        my $gd;
                        if ($x > 120 or $y > 120) {
                            $gd = $resize->resize(120,120);
                        }
                        else {
                            $gd = $resize->gd;
                        }
                        my $tfh = File::Temp->new(
                            TEMPLATE    => "poard_thumb_XXXXXXXX",
                            DIR         => $tmpdir,
                            UNLINK      => 0,
                        );
                        print $tfh $gd->$itype;
                        $upload->{thumbfile} = $tfh->filename;
                        close $tfh;
                    }
                }
            }
            elsif ($mt =~ m{^text/(?:plain|html)\z}) {
                local $/ = \4096;
                my $nl = 0;
                while (my $buffer = <$fh>) {
                    $nl += $buffer =~ tr/\n//;
                }
                $meta->{lines} = $nl;
            }
            close $fh;
        }
    }
    return (\@uploads, \@errors);
}

sub fetch_mimetype {
    my ($self, $flm, $file, $suffix) = @_;
    my $m = $flm->checktype_filename($file);
    my ($mt) = $m =~ m{^([\w-]+/[\w-]+)};
    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$mt], ['mt']);
    if ($mt eq 'text/x-c') {
        if ($suffix eq '.js') {
            $mt = 'text/javascript';
        }
    }
    elsif ($mt eq 'text/plain') {
        if ($suffix eq '.js') {
            $mt = 'text/javascript';
        }
        elsif ($suffix eq '.css') {
            $mt = 'text/css';
        }
    }
    elsif ($mt eq 'text/html') {
        if ($suffix eq '.mht') {
            $mt = 'multipart/related';
        }
    }
    my $conf = $self->get_attachment;
    if ($mt and not $conf->{types}->{$mt}) {
        if ($mt =~ m#^text/# and $conf->{types}->{"text/plain"}) {
            # force text/plain
            $mt = "text/plain";
        }
    }
    return $mt;
}

sub insert_thread_tags {
    my ($self, $battie, $thread, $tags) = @_;
    my $schema = $self->schema->{poard};
    my $uid = $battie->get_session->userid;
    my @tag_ids;
    for my $tag (@$tags) {
        my $exists = $schema->resultset('Tag')->find({
                name => $tag->get_name,
            }, {
            for => 'update'
        });
        if ($exists) {
            $thread->add_to_tags($exists);
        }
        else {
            $exists = $thread->add_to_tags({
                    name => $tag->get_name,
                });
        }
        push @tag_ids, $exists->id;
    }
    if ($uid) {
        $self->update_user_tags($battie, \@tag_ids, $uid);
    }
}

sub fetch_tags_from_form {
    my ($self, $battie, $args) = @_;
    my $tags = $args->{tags};
    my $plus = $args->{plus} || 0;
    my $prefix = $args->{prefix} || [];
    my $re = join '|', @$prefix;
    my $saved = $args->{saved} || [];
    my $request = $battie->request;
    my $schema = $self->schema->{poard};
    my %seen;
    my @params;
    for my $tag_id (@$saved) {
        my $exists = $schema->resultset('Tag')->find($tag_id);
        next unless $exists;
        my $ro = $exists->readonly;
        push @$tags, $ro;
    } 
    for my $key ($request->param) {
        next unless $key =~ m/^($re)$/;
        my @values = $request->param($key);
        push @params, @values;
    }
    for my $value (@params) {
        $value =~ s/^\s+//;
        $value =~ s/\s+\z//;
        $value =~ s/[^[:print:]]//g;
        next unless length $value;
        $seen{ $value }++ and next;
        my $exists = $schema->resultset('Tag')->find({
                name => $value,
            });
        my $ro;
        if ($exists) {
            $ro = $exists->readonly;
        }
        else {
            $ro = WWW::Poard::Model::Tag::Readonly->new({
                    name => $value,
                });
        }
        push @$tags, $ro;
    }
    for my $i (1 .. $plus) {
        my $ro = WWW::Poard::Model::Tag::Readonly->new({
                name => '',
            });
        push @$tags, $ro;
    }
    if (@$tags > 10) {
        @$tags = @$tags[0 .. 9];
    }
}

sub poard__admin_list_boards {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args = $request->get_args;
    $battie->response->set_no_cache(1);
    my $id = 0;
    my $board;
    if (@$args) {
        $self->init_db($battie);
        my $schema = $self->schema->{poard};
        ($id) = @$args;
        $board = $schema->resultset('Board')->find($id);
    }
    my $data = $battie->get_data;
    $data->{poard}->{board} = $board->readonly if $board;
    $data->{subtitle} = "Administrate Boards";
    my $tree = $self->create_board_tree($battie);
    $data->{poard}->{tree} = $tree;
}

#sub poard__mod_move_node {
#    my ($self, $battie) = @_;
#    my $request = $battie->request;
#    my $args = $request->get_args;
#    my ($thread_id, $msid) = @$args;
#    my $data = $battie->get_data;
#    $self->init_db($battie);
#    my $submit = $request->get_submit;
#    my $schema = $self->schema->{poard};
#    if ($submit->{move}) {
#        $battie->require_token;
#        my $thread = $self->check_existance($battie, Thread => $thread_id);
#        eval {
#            $schema->txn_do(sub {
#                my $msg = $schema->resultset('Message')->find($msid, { for => 'update' });
#                $self->exception("Argument", "Message '$msid' does not exist") unless $msg;
#                $self->exception("Argument", "Message '$msid' is not in thread '$thread_id'") unless $msg->thread_id == $thread_id;
#                die "test";
#            });
#        };
#        if (my $e = $@) {
#            warn __PACKAGE__.':'.__LINE__.": TRANSACTION FAILED: $e\n";
#            $battie->rethrow($e) if (ref $e) =~ m/^WWW::Battie/;
#            $self->exception("Argument", "Could not edit survey");
#        }
#    }
#    $data->{poard}->{thread_id} = $thread_id;
#    $data->{poard}->{msg_id} = $msid;
#}

sub poard__admin_edit_board {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    my $submit = $request->get_submit;
    my $id = $request->param('board.id') || 0;
    my $edit = $request->param('edit') ? 1 : 0;
    if (($submit->{split} or $submit->{up} or $submit->{down} or $submit->{save}) and not $battie->valid_token) {
        $battie->token_exception;
    }
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $board = $id ? $self->check_existance($battie, Board => $id) : undef;
    my $parent_id = $request->param('board.parent_id');
    my $parent = $parent_id ? $self->check_existance($battie, Board => $parent_id) : undef;
    $self->exception("Argument" => "Board is a leaf") if ($parent and $parent->readonly->is_leaf);


    my $data = $battie->get_data;

    if ($submit->{up} or $submit->{down}) {
        $self->exception(Argument => "No ID given") unless $id;
        $schema->txn_begin;
        eval {
            $board = $schema->resultset('Board')->find($id, { 'for' => 'update' })
                or die "Could not find board";
            my ($parent) = $schema->resultset('Board')
                ->direct_parent($board, { 'for' => 'update' })->all;
            die "Board has no parent" unless $parent;
            my $sibling = $schema->resultset('Board')
                ->sibling($board, $submit->{up} ? 'left' : 'right', { 'for' => 'update' })->single;
            my $move_orig = ($sibling->children_count + 1) * 2;
            my $move_sibling = ($board->children_count + 1) * 2;
            my $board_children = $schema->resultset('Board')->search({
                lft => { '>=', $board->lft },
                rgt => { '<=', $board->rgt },
            });
            my @ids;
            while (my $item = $board_children->next) {
                push @ids, $item->id;
            }
            $board_children = $schema->resultset('Board')->search({
                id => { 'IN' => \@ids },
            });
            my $sibling_children = $schema->resultset('Board')->search({
                lft => { '>=', $sibling->lft },
                rgt => { '<=', $sibling->rgt },
            });
            if ($submit->{up}) {
                $sibling_children->update({
                    lft => \("lft + $move_sibling"),
                    rgt => \("rgt + $move_sibling"),
                });
                $board_children->update({
                    lft => \("lft - $move_orig"),
                    rgt => \("rgt - $move_orig"),
                });
            }
            else {
                $sibling_children->update({
                    lft => \("lft - $move_sibling"),
                    rgt => \("rgt - $move_sibling"),
                });
                $board_children->update({
                    lft => \("lft + $move_orig"),
                    rgt => \("rgt + $move_orig"),
                });
            }
        };
        if ($@) {
            my $err = $@;
            $schema->txn_rollback;
            die $err;
        }
        else {
            $schema->txn_commit;
            $battie->writelog($board, "moved");
            $battie->set_local_redirect("/poard/admin_list_boards");
            $self->delete_all_board_caches($battie);
            return;
        }
    }
    elsif ($submit->{save} or $submit->{preview} or $edit) {
        my $tags_default = [];
        my $tags_example = [];
        my $plus = 3;
        if ($submit->{save}) {
            $plus = 0;
        }
        my @saved_tags_default;
        my @saved_tags_example;
        if ($board and not ($submit->{save} or $submit->{preview})) {
            my $meta = $board->meta || {};
            my $default = $meta->{tags}->{default};
            @saved_tags_default = split /,/, $default;
            my $example = $meta->{tags}->{example};
            @saved_tags_example = split /,/, $example;
        }
        my $result = $self->fetch_tags_from_form($battie, {
                tags => $tags_default,
                plus => $plus,
                prefix => ['tag_default'],
                saved => \@saved_tags_default,
            });
        $result = $self->fetch_tags_from_form($battie, {
                tags => $tags_example,
                plus => $plus,
                prefix => ['tag_example'],
                saved => \@saved_tags_example,
            });
        $data->{poard}->{default_tags} = $tags_default;
        $data->{poard}->{example_tags} = $tags_example;

        if ($submit->{save}) {
            my $name = $request->param('board.name');
            my $description = $request->param('board.description');
            my $grouprequired = $request->param('board.groupRequired') || 0;
            my $index = $request->param('board.bit.index');
            my $archive = $request->param('board.bit.archive');
            $schema->txn_begin;
            eval {
                my $meta = {
                    tags => {
                        default => '',
                        example => '',
                    },
                };
                my $count = $schema->resultset('Board')->count;
                for my $tag_type (['default', $tags_default], ['example', $tags_example]) {
                    my $tags = $tag_type->[1];
                    my $type = $tag_type->[0];
                    for my $tag (@$tags) {
                        my $exists = $schema->resultset('Tag')->find({
                                name => $tag->get_name,
                            }, {
                                for => 'update'
                            });
                        if ($exists) {
                        }
                        else {
                            $exists = $schema->resultset('Tag')->create({
                                    name => $tag->get_name,
                                });
                        }
                        $meta->{tags}->{$type} .= $exists->id . ",";
                    }
                    $meta->{tags}->{$type} =~ s/,$//;
                }
                unless ($count) {
                    my $top = $schema->resultset('Board')->insert_new(0, {
                        name => 'Board',
                        description => '',
                        grouprequired => 0,
                        position => 0,
                    });
                    $parent_id = $top->id;
                }
                if ($board) {
                    my $board_ro = $board->readonly;
                    $board->name($name);
                    $board->description($description);
                    $board->grouprequired($grouprequired);
                    $board->flags($board_ro->set_bit_index($index));
                    $board->flags($board_ro->set_bit_archive($archive));
                    $board->meta($meta);
                    $board->update;
                    $battie->writelog($board);
                }
                elsif ($parent_id) {
                    $board = $schema->resultset('Board')->insert_new($parent_id, {
                        name => $name,
                        description => $description,
                        grouprequired => $grouprequired,
                        position => 0,
                        meta => $meta,
                    });
                }
                else {
                    $self->exception(Argument => "No parent given");
                }

            };
            if ($@) {
                my $err = $@;
                $schema->txn_rollback;
                die $err;
            }
            else {
                $schema->txn_commit;
                $battie->writelog($board, "saved");
                $battie->set_local_redirect("/poard/admin_list_boards");
                $self->delete_all_board_caches($battie);
                return;
            }
        }
    }
    elsif ($submit->{split}) {
        $schema->txn_begin;
        eval {
            $board = $schema->resultset('Board')->find($id, { 'for' => 'update' });
            $self->exception("Argument" => "Board is not a leaf")
                unless $board->readonly->is_leaf;
            my $new_board = $schema->resultset('Board')->insert_new($board->id, {
                name => $board->name,
                description => $board->description,
                grouprequired => $board->grouprequired,
                position => 0,
            });
            my ($lft, $rgt) = ($new_board->lft, $new_board->rgt);
            $board = $schema->resultset('Board')->find($id, { 'for' => 'update' });
            warn __PACKAGE__.':'.__LINE__.": NEW ($lft, $rgt)\n";
            $new_board->update({
                lft => $board->lft,
                rgt => $board->rgt,
            });
            $board->update({
                lft => $lft,
                rgt => $rgt,
                name => $board->name . " *",
            });

        };
        if ($@) {
            my $err = $@;
            $schema->txn_rollback;
            die $err;
        }
        else {
            $schema->txn_commit;
            $battie->writelog($board, "splitted");
            $battie->set_local_redirect("/poard/admin_list_boards");
            $self->delete_all_board_caches($battie);
            return;
        }
    }



    my $group_required;
    if ($board) {
        my $ro = $board->readonly;
        $group_required = $ro->grouprequired;
        $data->{poard}->{board} = $ro;
    }
    elsif ($parent) {
        $group_required = $parent->grouprequired;
    }
    my @roles   = $battie->module_call( login => 'get_all_roles' );
    my $role_options = [$group_required,
        map {
            my $ro = $_->readonly;
            [$ro->get_id, $ro->get_name]
        } @roles
    ];
    $data->{poard}->{roles} = $role_options;
    $data->{poard}->{parent_id} = $parent_id;
    $data->{poard}->{parents} = $self->parents_to_board($battie, $schema, 0, $board);
    $self->make_board_breadcrumb($battie, $board);
}

sub delete_all_board_caches {
    my ($self, $battie) = @_;
    $battie->delete_cache('poard/board_list');
    $battie->to_cache('poard/board_list_mtime', time, 60 * 60 * 24);
    my $schema = $self->schema->{poard};
    my $search = $schema->resultset('Board')->search;
    while (my $board = $search->next) {
        my $bid = $board->id;
        my $ck = "poard/overview/$bid";
        warn __PACKAGE__.':'.__LINE__.": delete $ck\n";
        $battie->delete_cache($ck);
    }
    my $ck = "poard/overview/0";
    warn __PACKAGE__.':'.__LINE__.": delete $ck\n";
    $battie->delete_cache($ck);
}

sub get_sub_boards {
    my ($self, $board) = @_;
    return unless $board;
    if ($board =~ m/::Readonly/) {
        my $select = $self->schema->{poard}->resultset('Board')->find($board->id);
        return map $_->readonly, $select->sub_boards;
    }
    else {
        return $board->sub_boards;
    }
}

sub poard__start {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args = $request->get_args;
    my $board_id = 0;
    if (@$args) {
        # TODO numeric
        ($board_id) = @$args;
    }
    if ($board_id =~ tr/0-9//c) {
        $battie->not_found_exception("Board '$board_id' does not exist");
    }
    my $data = $battie->get_data;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};

    $data->{subtitle} = join " - ",
        $battie->translate("poard_overview"),
        $battie->translate("poard_board");
    my $tree = $self->create_start($battie, $board_id);
    $self->mark_read_threads($battie, [map { $_->latest || () } @$tree]);
    $self->filter_visible_boards($battie, $tree);
    my ($last) = sort { $b <=> $a } map {
        my $t = $_->latest;
        $t ? ($t->mtime_epoch || $t->ctime_epoch) : ()
    } @$tree;
    $battie->response->set_last_modified($last) if $last;
    $data->{poard}->{tree} = $tree;
    my $board = $board_id ? $schema->resultset('Board')->find($board_id) : undef;
    $self->make_board_breadcrumb($battie, $board) if $board_id;
    if ($battie->allow->can_do(poard => 'show_unapproved_messages')) {
        # show messages to approve
        my $onhold = $self->get_onhold($battie);
        $data->{poard}->{onhold} = $onhold;
    }
}

sub filter_visible_boards {
    my ($self, $battie, $tree) = @_;
    for (my $i = 0; $i < @$tree; $i++) {
        my $board = $tree->[$i];
        unless ($self->check_board_group($battie, $board)) {
            if ($board->is_leaf) {
                my $previous_down = $tree->[$i-1]->level_down || [];
                my $down = $tree->[$i]->level_down || [];
                if (@$down) {
                    push @$previous_down, @$down;
                    $tree->[$i-1]->set_level_down($previous_down);
                }
            }
            else {
                # move all sub boards one level up
                my $count = $board->children_count;
                my $last = $tree->[$i + $count];
                my $down = $last->level_down || [];
                pop @$down;
                for my $j (1 .. $count) {
                    my $b = $tree->[$i + $j];
                    $b->set_level($b->level - 1);
                }
            }
            splice @$tree, $i, 1;
            $i--;
        }
    }
    # delete all empty boards from the list
    for (my $i = 0; $i < @$tree - 1; $i++) {
        my $board = $tree->[$i];
        my $level = $board->level;
        my $next = $tree->[$i+1];
        if (!$board->is_leaf and $next->level <= $level) {
            splice @$tree, $i, 1;
            $i-=2;
        }
    }
}

sub create_start {
    my ($self, $battie, $board_id, $part_tree) = @_;
    my $schema = $self->schema->{poard};
    my $ck = "poard/overview/$board_id";
    my $tree_cache = $battie->from_cache($ck);
    my $select = [qw/ id name description lft rgt grouprequired /];
    unless ($tree_cache) {
        $part_tree ||= $self->create_board_tree($battie, $board_id, undef, $select);
        my $c = @$part_tree;
        warn __PACKAGE__.':'.__LINE__.": create_start($board_id, count $c)\n";
        my @part_trees;
        my @new_tree;
        if (@$part_tree > 1) {
            my @list = @$part_tree;
            push @new_tree, shift @list;
            my $level = $new_tree[0]->level + 1;
            my $index = -1;
            for my $board (@list) {
                if ($board->level == $level) {
                    $index++;
                }
                push @{ $part_trees[ $index ] }, $board;
            }
            for my $part (@part_trees) {
                my $board_id = $part->[0]->id;
                $_->set_level($_->level - 1) for @$part;
                my $result = $self->create_start($battie, $board_id, $part);
                $_->set_level($_->level + 1) for @$result;
                push @new_tree, @$result;
            }
        }
        else {
            # leaf
            my $board = $part_tree->[0];
            my $level = $board->level;
            my $name = $board->name;
            my $counts = $schema->resultset('Thread')->search({
                    status      => 'active',
                    board_id    => $board->id,
                },
                {
                    select => [
                        { sum => 'messagecount' },
                        { count => 'id' },
                    ],
                    as => [qw/ messagecount id /],
                });
            my $thread = $counts->next;
            $board->set_thread_count($thread->id);
            $board->set_answer_count($thread->messagecount);

            my $latest = $schema->resultset('Thread')->search(
                {
                    status => 'active',
                    board_id => $board->id,
                },
                {
                    rows => 1,
                    order_by => 'mtime desc',
                    select => [qw/ id title mtime solved board_id  is_tree /],
                }
            )->single;
            if ($latest) {
                my $tro = $latest->readonly([qw/ id title mtime solved is_tree /]);;
                my $msg = $latest->search_related(messages => {
                        status => 'active',
                    },
                    {
                        order_by => 'position desc',
                        rows => 1,
                        select => [qw/ id mtime ctime author_id author_name /],
                    })->single;
                if ($msg) {
                    my $msg_ro = $msg->readonly([qw/ id author_id author_name /]);
                    if ($msg->author_id) {
                        my $user = $battie->module_call(login => 'get_user_by_id', $msg->author_id);
                        $msg_ro->set_author($user->readonly([qw/ id nick /]));
                    }
                    else {
                        $msg_ro->set_author_name($msg->author_name);
                    }
                    $tro->set_last($msg_ro);
                    if ($tro->mtime) {
                        $tro->set_mtime_epoch($tro->mtime->epoch);
                        $tro->set_mtime(undef);
                    }
                }
                $board->set_latest($tro);
            }
            push @new_tree, $board;
        }
        $battie->to_cache($ck, \@new_tree, 60 * 60 * 12);
        $tree_cache = \@new_tree;
    }
    return $tree_cache;
}

sub create_board_tree {
    my ($self, $battie, $board_id, $type, $select) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $search = $schema->resultset('Board')->fetch_tree($board_id)
        or $battie->not_found_exception("Board '$board_id' does not exist");
    my $tree = $search->make_tree($type, $select);
#    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$tree], ['tree']);
    return $tree;
}

sub get_overview {
    my ($self, $battie, $board) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $ov = $battie->module_call(cache => 'from_cache', 'poard/overview/'.$board->id);
    unless ($ov) {
        my @sub_boards;
        my @subs = $schema->resultset('Board')->search(
            { parent_id => $board->id },
            { order_by => 'position ASC' }
        )->all;
        for my $sub (@subs) {
            my $latest = $sub->search_related(threads =>
                {
                    status => 'active',
                },
                {
                    rows => 1,
                    order_by => 'mtime desc',
                }
            )->single;
            my $ro = $sub->readonly([ $sub->default_fields ]);
            if ($latest) {
                my $tro = $latest->readonly;
                my $msg = $latest->search_related(messages => {
                        status => 'active',
                    },
                    { order_by => 'position desc', rows => 1})->single;
                my $msg_ro = $msg->readonly;
                if ($msg->author_id) {
                    my $user = $battie->module_call(login => 'get_user_by_id', $msg->author_id);
                    $msg_ro->set_author($user->readonly);
                }
                else {
                    $msg_ro->set_author_name($msg->author_name);
                }
                $tro->set_last($msg_ro);
                $ro->set_latest($tro);
            }
            my @threads = $sub->search_related(threads =>
                {
                    status => 'active'
                }
            )->all;
            $ro->set_thread_count(scalar @threads);
            my $acount = 0;
            for my $t (@threads) {
                $acount += $t->messagecount;
            }
            $ro->set_answer_count($acount);
            push @sub_boards, $ro;
        }
        $ov = $board;
        $ov->set_sub_boards(\@sub_boards);
        $battie->module_call(cache => 'cache', 'poard/overview/'.$board->id, $ov, 3 * 60);
    }
    return $ov;
}

sub poard__edit_survey {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args    = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $submit = $request->get_submit;
    my $schema = $self->schema->{poard};
    my $survey = $schema->resultset('Survey')->find($id);
    my $thread = $survey->thread;
    my $own = 0;
    my $can_change = $battie->get_allow->can_do(poard => 'edit_survey_change');
    if ($thread->author_id and $thread->author_id == $battie->get_session->userid) {
        $own = 1;
    }
    if (not $can_change and not $own) {
        $self->exception("Argument", "Survey '$id' cannot be edited by you");
    }
    if ($submit->{change}) {
        $battie->require_token;
        return;
    }
    if ($submit->{add}) {
        $battie->require_token;

        my $answer = $request->param('answer');
        if (not defined $answer or not length $answer) {
            $self->exception("Argument", "Missing option");
        }

        eval {
            $schema->txn_do(sub {
                my $max_option = $schema->resultset('SurveyOption')->search({
                        survey_id => $survey->id,
                    },
                    {
                        order_by => 'position desc',
                        rows => 1,
                        for => 'update',
                    })->single;
                my $max_position = $max_option->position + 1;
                if ($max_position > 30) {
                    $self->exception("Argument", "Already maximum no. of options");
                }
                my $option = $schema->resultset('SurveyOption')->create({
                        survey_id   => $survey->id,
                        answer      => $answer,
                        position    => $max_position,
                        ctime       => undef,
                    });
            });
        };
        if (my $e = $@) {
            warn __PACKAGE__.':'.__LINE__.": TRANSACTION FAILED: $e\n";
            $battie->rethrow($e) if (ref $e) =~ m/^WWW::Battie/;
            $self->exception("Argument", "Could not edit survey");
        }
        $battie->set_local_redirect("/poard/edit_survey/" . $survey->id);
        my $ck = "poard/thread_surveys/" . $thread->id;
        $battie->delete_cache($ck);
        $battie->writelog($thread);
        return;

    }
    my $survey_ro = $survey->readonly;
    my $data = $battie->get_data;
    my @options = map {
        my $ro = $_->readonly([qw/ id answer position /]);
        $ro
    } $survey->search_related('options', {}, {
        select => [qw/ id answer position /],
    });
    $survey_ro->set_options(\@options);
    $survey_ro->set_thread($thread->readonly([qw/ id title /]));

    $data->{poard}->{survey} = $survey_ro;
}

sub poard__close_survey {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args    = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $submit = $request->get_submit;
    my $schema = $self->schema->{poard};
    my $survey = $schema->resultset('Survey')->find($id);
    my $thread = $survey->thread;
    if ($submit->{close}) {
        $battie->require_token;
        my $can_close = $battie->get_allow->can_do(poard => 'mod_close_survey');
        unless ($can_close) {
            if (!$thread->author_id or $thread->author_id != $battie->get_session->userid) {
                $self->exception("Argument", "Survey '$id' cannot be closed by you");
            }
        }
        if ($survey->status eq 'closed') {
            $self->exception("Argument", "Survey '$id' already closed");
        }
        if ($survey->status eq 'onhold' or $survey->status eq 'deleted') {
            $self->exception("Argument", "Survey '$id' not editable");
        }
        $survey->update({
                status => 'closed',
            });
        my $ck = "poard/thread_surveys/" . $thread->id;
        $battie->delete_cache($ck);
        $battie->set_local_redirect("/poard/thread/" . $thread->id);
        $battie->writelog($thread);
    }
}

sub poard__survey_vote {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args    = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $submit = $request->get_submit;
    my $schema = $self->schema->{poard};
    my $survey = $schema->resultset('Survey')->find($id);
    $self->exception("Argument", "Survey '$id' does not exist") unless $survey;
    my $thread = $survey->thread;
    my $board = $self->fetch_boards($battie, $thread->board_id);
    my $thread_ro = $thread->readonly;
    $thread_ro->set_board($board);
    $self->check_visibility($battie, $thread_ro);
    my $data = $battie->get_data;
    if ($submit->{vote} or $submit->{abstain}) {
        $self->exception("Argument", "Thread '".$thread->id."' is closed") if $thread->closed;
        my $voted = $schema->resultset('SurveyVote')->find({ survey_id => $id, user_id => $battie->get_session->userid});
        $self->exception("Argument", "You have already voted on Survey '$id'") if $voted;
        $battie->require_token;
        my @selected;
        my @options = $survey->search_related('options');
        my $multiple = $survey->is_multiple;
        my @param_options = $request->param('option.position');
        if ($submit->{abstain}) {
            @param_options = ();
        }
        my %selected = map { $_ => 1 } @param_options;
        if ($submit->{vote} and not keys %selected) {
            $self->exception("Argument", "Select option(s) or abstain from voting");
        }
        eval {
            $schema->txn_do(sub {
                my $vote_info = [];
                for my $opt (@options) {
                    my $sel = $selected{ $opt->position };
                    if ($sel) {
                        push @$vote_info, $opt->position;
                        push @selected, $sel;
                        $opt->votecount(\'votecount + 1');
                        $opt->update;
                    }
                    last if @selected >= ($multiple || 1);
                }
                $vote_info = undef if $request->param('do_not_log');
                my $meta = { voted => $vote_info };
                $voted = $schema->resultset('SurveyVote')->create({
                        survey_id   => $id,
                        user_id     => $battie->get_session->userid,
                        meta        => $meta,
                    });
                $survey->votecount(\'votecount + 1');
                $survey->update;
                $thread->mtime(DateTime->now);
                $thread->update;
            });
        };
        if (my $e = $@) {
            warn __PACKAGE__.':'.__LINE__.": TRANSACTION FAILED: $e\n";
            $self->exception("SQL", "Could not vote");
        }
        my $ck = "poard/thread_surveys/" . $thread->id;
        $battie->delete_cache($ck);
        $battie->set_local_redirect("/poard/thread/" . $thread->id);
        $battie->writelog($thread);
    }
    elsif ($submit->{show_my_vote}) {
        my $voted = $schema->resultset('SurveyVote')->find({ survey_id => $id, user_id => $battie->get_session->userid});
        my $meta = $voted->meta || {};
        my $votes = $meta->{voted} || [];
        my $ro = $voted->readonly;
        my %vote_options;
        @vote_options{ @$votes } = ();
        my $ajax = $request->param('is_ajax');
        if ($ajax) {
            $battie->response->set_content_type('text/plain');
            $data->{main_template} = undef;
            my $votes_json = eval { to_json($votes) } || '[]';
            if ($@) {
                warn __PACKAGE__.':'.__LINE__.": ERROR $@\n";
            }
            $battie->response->set_output($votes_json);
            return;
        }
        else {
            my @options = $survey->search_related('options', {}, { select => [qw/ answer position /] });
            my @options_ro;
            for my $opt (@options) {
                my $ro = $opt->readonly([qw/ answer position /]);
                if (exists $vote_options{ $opt->position }) {
                    $ro->set_myvote(1);
                }
                push @options_ro, $ro;
            }
            $data->{poard}->{voted} = \@options_ro;
        }
    }
}

sub poard__create_survey {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args    = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($board_id) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $board = $schema->resultset('Board')->find($board_id);
    $self->exception("Argument", "Board '$board_id' does not exist") unless $board;
    # TODO
    #$self->check_visibility($battie, $thread);
    $battie->not_found_exception("Board '$board_id' is not visible by you", [])
        unless $self->check_board_group($battie, $board);
    $self->exception("Argument", "Board '$board_id' is a superboard") unless $board->is_leaf;
    my $from_form = $request->param('form');
    my $correct_bbcode = $request->param('correct_bbcode');
    my $correct_urls = $request->param('correct_urls');
    my $submit = $request->get_submit;
    my $answer_count = $request->param('answer_count') || 5;
    # TODO
    if ($answer_count > 30) {
        $answer_count = 30;
    }
    my $data = $battie->get_data;
    if ($self->get_post_hint) {
        $data->{poard}->{post_hint} = 1;
    }
    $data->{poard}->{create_survey} = 1;
    my $question       = $request->param('survey.question');
    my $text        = $request->param('message.message');
    my $title          = $request->param('survey.title');
    my $subscribe = $request->param('subscribe');
    $data->{poard}->{subscribe} = $subscribe;

    my $tags = [];
    my ($tags_default, $tags_example, $tags_user) = $self->thread_default_tags($battie, $board);
    $data->{poard}->{tags_example} = $tags_example;
    $data->{poard}->{tags_default} = $tags_default;
    $data->{poard}->{tags_user} = $tags_user;
    my $uid = $battie->get_session->userid;

    if ($submit->{preview} or $submit->{save}) {
        my $result = $self->_check_message($battie, $text, {
                links => $correct_urls,
                bbcode => $correct_bbcode,
            });
        my $error = $result->{error};
        if (@$error) {
            $text = $result->{text};
            for my $e (@$error) {
                $data->{poard}->{error}->{message}->{$e} = 1;
            }
        }
        if (@$error and $submit->{save}) {
            $submit->{preview} = delete $submit->{save};
        }
        if ($submit->{save}) {
            $text = $result->{text};
        }
    }


    if ($submit->{save}) {
        my $can_post = $battie->get_allow->can_do(poard => 'post_answer_authorized');
        if (!$battie->session->userid) {
            # we have a guest
            $self->exception("Argument", "You must be logged in to create a survey");
        }
        elsif (not $battie->valid_token) {
            $data->{poard}->{error}->{token} = 1;
            $submit->{preview} = delete $submit->{save};
        }
        elsif (not defined $question or not length $question) {
            $data->{poard}->{error}->{no_question} = 1;
            $submit->{preview} = delete $submit->{save};
        }
        elsif (not defined $text or $text !~ m/\S/) {
            $data->{poard}->{error}->{no_text} = 1;
            $submit->{preview} = delete $submit->{save};
        }
        elsif (length $text > 10_000) {
            $data->{poard}->{error}->{long_text} = 1;
            $submit->{preview} = delete $submit->{save};
        }
        elsif (!$can_post) {
            # first check how many unapproved threads we have in the board
            my $max = $self->get_max_unapproved_threads || 0;
            if ($max) {
                my $count = $schema->resultset('Thread')->count(
                    {
                        board_id => $board_id,
                        status => 'onhold',
                    }
                );
                if ($count >= $max) {
                    $data->{poard}->{error}->{max_unapproved_threads} = 1;
                    $submit->{preview} = delete $submit->{save};
                }
            }
        }
    }
    if ($submit->{preview} or $submit->{save}) {
        my $plus = $submit->{save} ? 0 : 3;
        unless ($request->param('tags')) {
            push @$tags, @$tags_default;
        }
        my $result = $self->fetch_tags_from_form($battie, {
                tags => $tags,
                plus => $plus,
                prefix => ['tag', 'tag_new'],
            });
        $data->{poard}->{use_tags} = $tags;
    }
    if ($submit->{preview} or $submit->{add_answers} or $submit->{save}) {
        if (not defined $title or not length $title) {
            $title = $question;
        }
        my @answers;
        for my $aid (1 .. $answer_count) {
            my $answer = $request->param('survey_option.' . $aid . '.text');
            push @answers, $answer if defined $answer and length $answer;
        }
        my $is_multiple    = $request->param('survey.is_multiple');
        my $multiple_count = $request->param('survey.multiple_count');
        if ($submit->{preview} or $submit->{add_answers}) {
            $battie->response->set_no_cache(0); # otherwise textarea will be emptied
            push @answers, ('') x 5 if $submit->{add_answers} || @answers == 0;
            my @answer_list = (
                map {
                    +{
                        id => $_+1,
                        value => $answers[$_],
                    }
                } 0..$#answers
            );
            my $message_ro = WWW::Poard::Model::Message::Readonly->new({
                    message => $text,
                });
            my $re = $battie->get_render->render_message_html($message_ro->message);
            $message_ro->set_rendered($re);
            $multiple_count ||= 'all';
            $data->{poard}->{survey}->{answers}        = \@answer_list;
            $data->{poard}->{survey}->{answer_count}   = @answer_list;
            $data->{poard}->{survey}->{question}       = $question;
            $data->{poard}->{survey}->{message}        = $text;
            $data->{poard}->{survey}->{title}          = $title;
            $data->{poard}->{survey}->{multiple_count} = $multiple_count;
            $data->{poard}->{survey}->{is_multiple}    = $is_multiple;
            $data->{poard}->{message}          = $message_ro;
            #$data->{poard}->{rendered_message} = $re;
            $data->{poard}->{board}            = $board->readonly;
        }
        elsif ($submit->{save}) {
            my $multiple = 0;
            if ($is_multiple) {
                if ($multiple_count eq 'all') {
                    $multiple = @answers;
                }
                else {
                    $multiple = $multiple_count;
                    $multiple =~ tr/0-9//cd;
                    $multiple += 0;
                }
            }
            my $can_post = $battie->get_allow->can_do(poard => 'post_answer_authorized');
            $schema->txn_begin;
            my $thread;
            my $message;
            eval {
                $thread = $schema->resultset('Thread')->create({
                        title => ( length $title ? $title : $question ),
                        status       => 'onhold',
                        board_id      => $board_id,
                        author_id     => $battie->get_session->userid || 0,
                        messagecount => 0,
                        is_survey    => 1,
                        status       => $can_post ? 'active' : 'onhold',
                        is_tree => 1,

                        # TODO should guests create surveys?
                        #$can_post ? () : (author_name => $author_name),
                        ctime => undef,
                    });
                $message = $schema->resultset('Message')->insert_new(0, {
                        author_id => $battie->get_session->userid || 0,
                        message  => $text,
                        status   => $can_post ? 'active' : 'onhold',
                        thread   => $thread,
                        ctime    => undef,
                        position => 0,
                    }
                );
                my $survey = $schema->resultset('Survey')->create({
                        thread      => $thread,
                        question    => $question,
                        is_multiple => $multiple,
                        status      => $can_post ? 'active' : 'onhold',
                        ctime       => undef,
                    });
                for my $aid (0..$#answers) {
                    my $option = $schema->resultset('SurveyOption')->create({
                            survey   => $survey,
                            answer   => $answers[$aid],
                            position => $aid + 1,
                            ctime    => undef,
                        });
                }
                if (@$tags) {
                    $self->insert_thread_tags($battie, $thread, $tags);
                }
                $self->update_user_settings($battie, $message->author_id);
                if ($can_post) {
                    $self->update_search_index($battie, update => thread => $thread->id);
                    #$self->update_search_index($battie, update => message => $message->id);
                }
                if ($subscribe) {
                    my $notify = $schema->resultset('Notify')->create({
                            user_id       => $battie->get_session->userid,
                            thread_id     => $thread->id,
                            ctime         => undef,
                            last_notified => undef,
                        });
                }
                $self->delete_latest_cache($battie, $thread->board);
            };
            if ($@) {
                $schema->txn_rollback;
                $self->exception("SQL", "Could not create survey");
            }
            else {
                unless ($can_post) {
                    $battie->delete_cache('poard/onhold');
                }
                $battie->writelog($thread, "created survey");
                $battie->writelog($message, "created survey");
                $schema->txn_commit;


                if ($can_post) {
                    $battie->set_local_redirect("/poard/thread/" . $thread->id);
                }
                else {
                    $battie->set_local_redirect("/poard/create_thread/$board_id?confirmation=1;thread_id=" . $thread->id);
                }
            }
        }
    }
    $self->make_board_breadcrumb($battie, $board);
    $data->{poard}->{correct_bbcode} = $from_form ? $correct_bbcode : 1;
    $data->{poard}->{correct_urls} = $from_form ? $correct_urls : 1;
}

sub poard__settings {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args    = $request->get_args;
    my ($what) = @$args;
    $what ||= '';
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $data = $battie->get_data;
    $data->{poard}->{setting} = $what;
    my $profile = $battie->fetch_settings('ro');
    my $settings = $profile ? $profile->meta : {};
    my $submit = $request->get_submit;
    if ($submit->{save}) {
        $battie->require_token;
    }
    if ($what eq 'edit') {
        my $set = $settings->{poard}->{edit} || $defaults{edit};
        $data->{settings}->{poard}->{edit} = $set;
        if ($submit->{save}) {
            my $cols = $request->param('settings.textarea.cols');
            my $rows = $request->param('settings.textarea.rows');
            {
                no warnings;
                $cols = int $cols;
                $rows = int $rows;
            }
            my $subscribe = $request->param('settings.subscribe') || 0;
            warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$subscribe], ['subscribe']);
            my $profile = $battie->fetch_settings('rw');
            my $settings = $profile ? $profile->meta : {};
            $settings->{poard}->{edit} = {
                textarea    => {
                    cols    => $cols,
                    rows    => $rows,
                },
                subscribe   => $subscribe ? 1 : 0,
            };
            $profile->meta($settings);
            $profile->update;
            $battie->set_local_redirect("/poard/settings/edit");
            $battie->delete_cache('member/settings/' . $battie->session->userid);
            return;
        }
    }
    elsif ($what eq 'articles') {
        my $set = $settings->{poard}->{articles} || $defaults{articles};
        $data->{settings}->{poard}->{articles} = $set;
        if ($submit->{save}) {
            my $avatar = $request->param('settings.avatar');
            my $hide_old_branches = $request->param('settings.hide_old_branches') || 0;
            $hide_old_branches =~ tr/0-9//cd;
            my $sig = $request->param('settings.signature');
            my $codebox_y = $request->param('settings.codebox.y') || 0;
            $codebox_y =~ tr/0-9//cd;
            my $codebox_x = $request->param('settings.codebox.x') || 0;
            $codebox_x =~ tr/0-9//cd;
            my $profile = $battie->fetch_settings('rw');
            my $settings = $profile ? $profile->meta : {};
            $settings->{poard}->{articles} = {
                avatar => $avatar ? 1 : 0,
                signature => $sig ? 1 : 0,
                codebox_y => $codebox_y,
                codebox_x => $codebox_x,
                hide_old_branches => $hide_old_branches,
            };
            $profile->meta($settings);
            $profile->update;
            $battie->set_local_redirect("/poard/settings/articles");
            $battie->delete_cache('member/settings/' . $battie->session->userid);
            return;
        }
    }
    elsif ($what eq 'overview') {
        my $set = $settings->{poard}->{overview} || $defaults{overview};
        $data->{settings}->{poard}->{overview} = $set;
        my %hidden = (map { $_ => 1 } split m/,/, $set->{hidden} || '');
        my $options = $self->create_board_options($battie);
        my %allowed = (map { $_->[0] => 1 } @$options);
        my $options1 = [];
        my $options2 = [];
        for my $board (@$options) {
            if ($hidden{ $board->[0] }) {
                push @$options1, $board;
            }
            else {
                push @$options2, $board;
            }
        }
        $data->{poard}->{options1} = [undef, @$options1];
        $data->{poard}->{options2} = [undef, @$options2];
        my $hide = "";
        if ($submit->{hide} or $submit->{show}) {
            if ($submit->{hide}) {
                my @ids = grep { $allowed{ $_ } } $request->param('settings.hide');
                @hidden{ @ids } = ();
            }
            elsif ($submit->{show}) {
                my @ids = grep { $allowed{ $_ } } $request->param('settings.show');
                delete @hidden{ @ids };
            }
            my $hide = join ',', sort keys %hidden;
            my $profile = $battie->fetch_settings('rw');
            my $settings = $profile ? $profile->meta : {};
            $settings->{poard}->{overview}->{hidden} = $hide;
            $profile->meta($settings);
            $profile->update;
            $battie->set_local_redirect("/poard/settings/overview");
            $battie->delete_cache('member/settings/' . $battie->session->userid);
            return;
        }
        elsif ($submit->{save_subs}) {
            my $subs = $request->param('settings.subs');
            my $profile = $battie->fetch_settings('rw');
            my $settings = $profile ? $profile->meta : {};
            $settings->{poard}->{overview}->{show_subs} = $subs ? 1 : 0;
            $profile->meta($settings);
            $profile->update;
            $battie->set_local_redirect("/poard/settings/overview");
            $battie->delete_cache('member/settings/' . $battie->session->userid);
            return;
        }
    }
    $battie->crumbs->append("Settings", "poard/settings");
    $battie->crumbs->append("$what", "poard/settings/$what") if $what;
}


sub get_thread_title_by_id {
    my ($self, $battie, $id) = @_;
    my $ck = "poard/thread_title/$id";
    my $title = $battie->from_cache($ck);
    unless (defined $title) {
        warn __PACKAGE__.':'.__LINE__.": title $id\n";
        $self->init_db($battie);
        my $thread = $self->schema->{poard}->resultset('Thread')->find(
            $id, { select => [qw/ title /] },
        );
        $title = $thread ? $thread->title : "Thread $id?";
        my $enc_title = encode_utf8($title);
        $battie->to_cache($ck, $enc_title, 60 * 60 * 24 * 30);
    }
    else {
        $title = decode_utf8($title);
    }
    return $title;
}

sub get_thread_by_id {
    my ($self, $battie, $id) = @_;
    $self->init_db($battie);
    my $thread = $self->schema->{poard}->resultset('Thread')->find($id);
}

sub get_board_by_id {
    my ($self, $battie, $id) = @_;
    $self->init_db($battie);
    my $board = $self->schema->{poard}->resultset('Board')->find($id);
}

sub get_board_title_by_id {
    my ($self, $battie, $id) = @_;
    my $board = $self->fetch_boards($battie, $id);
    return $board ? $board->name : "Board $id?";
}
sub get_board_view_by_id {
    my ($self, $battie, $id) = @_;
    my $board = $self->fetch_boards($battie, $id);
    return $board;
}

sub cron_notify {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{poard};
    my $user_schema = $self->schema->{user};
    my $interval = "30 MINUTE";
    my $minus = DateTime->now->subtract(minutes => 5);

    my $max_notified = $schema->resultset('Notify')->search({
        },
        {
            select => [
            { max => 'last_notified' },
            ],
            as => [qw/ last_notified /],
        })->single;
    my $max = $max_notified ? $max_notified->last_notified : DataTime->now;
    print "<<<<< $max >>>>>>\n";

    my $search = $schema->resultset('Notify')->search({
            last_notified => { '<' => $minus },
            'thread.mtime' => { '>=', $max },
        }, { prefetch => 'thread' });
    my %notifies;
    my $co = 0;
    while (my $notify = $search->next) {
        $co++;
        #warn __PACKAGE__.':'.__LINE__.": notify\n";
        my $thread = $notify->thread;
        my $last_notified = $notify->last_notified;
        my $user_id = $notify->user_id;
        if ($thread->mtime gt $last_notified) {
            unless ($notifies{$user_id}) {
                my $user = $user_schema->resultset('User')->find($user_id);
                $notifies{$user_id}->{user} = $user;
            }
            my $ro = $thread->readonly;
            my $data = {
                thread => $ro,
                msgs => [],
            };
            my $last = $thread->search_related('messages',
                {
                    ctime => { '>=' , $last_notified },
                    status => 'active',
                }, {
                    order_by => 'ctime desc',
                });
            my $msid = $notify->msg_id;
            my ($lft, $rgt, $pos);
            my $is_tree = 0;
            if ($msid) {
                $is_tree = $thread->is_tree;
                my $msg = $schema->resultset('Message')->find($msid);
                if ($is_tree) {
                    ($lft, $rgt) = ($msg->lft, $msg->rgt);
                }
                else {
                    $pos = $msg->position;
                }
            }
            while (my $msg = $last->next) {
                my $ro = $msg->readonly;
                my $author_id = $ro->author_id;
                # no notifications for your own messages
                next if $author_id && $author_id == $notify->user_id;
                if ($msid) {
                    if ($is_tree) {
                        next if ($msg->lft < $lft or $msg->rgt > $rgt);
                    }
                    else {
                        next if $msg->position < $pos;
                    }
                }
                my $author_name = $ro->author_name;
                if ($author_id) {
                    my $user = $battie->module_call(login => 'get_user_by_id', $author_id);
                    $author_name = $user->nick;
                    $ro->set_author_name($author_name);
                }
                push @{ $data->{msgs} }, $ro;
            }
            push @{ $notifies{$user_id}->{threads} }, $data if @{ $data->{msgs} };
        }
        $notify->update({last_notified => DateTime->now});
    }
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%notifies], ['notifies']);
    print STDERR "Searched $co threads\n";
    my $sent = 0;
    $battie->init_timezone_translation('default', 'de_DE');
    my $htc = $battie->create_htc(
        filename => 'poard/notify_subscribed.txt',
        path => $battie->template_path,
        default_escape => 0,
    );
    my $param = $battie->get_template_param;
    unless ($param) {
        $param = {};
        $battie->set_template_param($param);
    }
    $battie->fill_global_template_params($param);
    for my $user_id (keys %notifies) {
        my $user = $notifies{$user_id}->{user};
        my $threads = $notifies{$user_id}->{threads};
        next unless @{ $threads || []};
        my $profile = $user->profile;
        my $nick = $user->nick;
        my $email = $profile->email;
        warn __PACKAGE__.':'.__LINE__.": sending email to $nick ($email)\n";
        my $data = $battie->get_data;
        $data->{poard}->{user} = $user->readonly;
        $data->{poard}->{threads} = $threads;
        $htc->param( %$param );
        my $body = $htc->output;
        #warn __PACKAGE__.':'.__LINE__.": BODY: $body\n";
        $battie->send_mail({
            to => $email,
            subject => "$param->{title} - Notification",
            body => $body,
        });

        $sent++;
    }
    return $sent;
}

sub delete_latest_cache {
    # delete poard/latest/24h|7d from cache
    my ($self, $battie, $board_id) = @_;
    $battie->delete_cache('poard/latest24');
    $battie->delete_cache('poard/latest7d');

    $self->delete_board_cache($battie, $board_id);
}

sub delete_board_cache {
    my ($self, $battie, $board_id) = @_;

    my $board;
    my $schema = $self->schema->{poard};
    my $search = $schema->resultset('Board')->fetch_tree();
    my $tree = $search->make_tree('');
    if (ref $board_id) {
        $board = $board_id->readonly;
    }
    elsif (defined $board_id) {
        for my $item (@$tree) {
            if ($item->id == $board_id) {
                $board = $item;
                last;
            }
        }
    }
    if ($board) {
        my $board_id = $board->id;
        if ($board->is_leaf) {
            my $ck = "poard/board_info/$board_id";
            warn __PACKAGE__.':'.__LINE__.": delete_cache board_info $board_id\n";
            $battie->delete_cache($ck);
        }
    }
    my ($lft, $rgt);
    ($lft, $rgt) = ($board->get_lft, $board->get_rgt) if $board;
    for my $item (@$tree) {
        if ($board) {
            if ($item->get_lft < $lft and $item->get_rgt > $rgt) {
                warn __PACKAGE__.':'.__LINE__.": delete_cache overview @{[ $item->id ]}\n";
                # is a parent of $board
                $battie->delete_cache("poard/overview/" . $item->id);
            }
            elsif ($item->id == $board->id) {
                warn __PACKAGE__.':'.__LINE__.": delete_cache overview @{[ $item->id ]}\n";
                $battie->delete_cache("poard/overview/" . $item->id);
            }
        }
        else {
            warn __PACKAGE__.':'.__LINE__.": delete_cache overview @{[ $item->id ]}\n";
            $battie->delete_cache("poard/overview/" . $item->id);
        }
        if ($item->get_lft == 1) {
            warn __PACKAGE__.':'.__LINE__.": delete_cache overview 0\n";
            $battie->delete_cache("poard/overview/0");
        }
    }
}

sub delete_thread_cache {
    my ($self, $battie, $thread) = @_;
    my $tid = $thread->id;
    $self->delete_latest_cache($battie, $thread->board);
    my $ck = "poard/threadtree/$tid";
    $battie->delete_cache($ck);
    if (my $meta = $thread->meta) {
        for my $key (keys %{ ($meta || {})->{subtrees} }) {
            $battie->delete_cache("$ck/$key");
        }
    }
    #$battie->delete_cache("poard/message_authors/$tid");
    $battie->delete_cache("poard/thread_header/$tid");
}

sub reset_thread_cache {
    my ($self, $battie, $thread, $type) = @_;
    $type ||= "set";
    my @tags = $thread->tags;
    @tags = map { $_->readonly } @tags;
    my $thread_ck = "poard/thread_info/" . $thread->id;
    my $thread_ro = $thread->readonly;
    $self->_times_for_cache($thread_ro);
    $thread_ro->set_tags(\@tags);
    my $method = $type eq 'add' ? 'to_cache_add' : 'to_cache';
    $battie->$method($thread_ck, $thread_ro, time + CACHE_THREAD_HEADER);
    my $ck = "poard/thread_header/" . $thread->id;
    $battie->delete_cache($ck);
    return $thread_ro;
}


1;
