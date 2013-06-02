package WWW::Battie::Modules::Blog;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module::Model';
#use base 'Class::Accessor::Fast';
use base 'WWW::Battie::Accessor';
#__PACKAGE__->follow_best_practice;
__PACKAGE__->follow_good_practice;
__PACKAGE__->mk_accessors(qw/ image_url rss_title /);
use File::Copy qw/ move /;
use Text::Textile;
my %functions = (
    functions => {
        blog => {
            start        => 1,
            list_blog    => 1,
            theme        => 1,
            xml_rss      => {
                # won't create a session, or update the current session
                # will set a dummy session
                no_session => 1,
            },
            show_news    => {
                on_run => 1,
            },
            create_blog  => 1,
            create_theme => 1,
            edit_theme   => 1,
            edit_blog    => 1,
        },
    },
);
sub functions { %functions }

sub default_actions {
    my ($class, $battie) = @_;
    return {
        guest => [qw/ start theme xml_rss show_news list_blog /],
        blogadmin => [qw/ create_blog create_theme edit_theme /],
    };
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        return {
            link => ['blog', 'start'],
            image => "blog.png",
            text => 'Blog',
        };
    };
}

sub model {
    blog => 'WWW::Battie::Model::DBIC::Blog'
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$args], ['args']);
    my $url = $args->{PUBLIC_IMAGE_URL};
    my $self = $class->new({
            image_url => $url,
            rss_title => $args->{RSS_TITLE},
        });
}

sub image_dir {
    my ($self, $battie) = @_;
    my $docroot = $battie->get_paths->{docroot};
    my $url = $self->image_url;
    my $dir = $docroot . $url;
    return $dir;
}

sub blog__xml_rss {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    $battie->response->set_needs_navi(0);
    my $request = $battie->get_request;
    my $data = $battie->get_data;
    my $news = $self->create_latest_news_list($battie);
    $data->{latest_news_rss}->{list} = $news;
    $data->{latest_news_rss}->{title} = $self->rss_title;
    my $response = $battie->get_response;
    $response->set_content_type('text/xml');
}

sub create_latest_news_list {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $news = $battie->from_cache('blog/latest_news');
    unless($news) {
        my $schema = $self->get_schema->{blog};
        my $theme_rs = $schema->resultset('Theme');
        my $news_search = $theme_rs->search(
                {
                    active => 1,
                    #is_news => 1,
                },
                {
                        order_by => 'ctime desc',
                        rows => 20,
                },
        );
        my @news;
        while (my $news = $news_search->next) {
            my $ro = $news->readonly([qw/ id blog_id title abstract image posted_by active ctime blog /]);
            my $user = $battie->module_call(login => 'get_user_by_id', $news->posted_by);
            $ro->set_posted_by_user( $user->readonly([qw/ id nick /]) );
            push @news, $ro;
        }
        $news = \@news;
        $battie->to_cache('blog/latest_news', $news, 60 * 20);
    }
    return $news;
}


sub blog__show_news {
    my ($self, $battie) = @_;
    return unless $battie->response->get_needs_navi;
    my $cached = $battie->from_cache('blog/latest');
    my $blog;
    #$battie->timer_step("blog__show_news start");
    unless ($cached) {
        $self->init_db($battie);
        #$battie->timer_step("blog__show_news db");
        my $request = $battie->get_request;
        my $schema = $self->get_schema->{blog};
        my $blog_rs = $schema->resultset('Theme');
		$blog = $blog_rs->search(
				{
                    active => 1,
                    is_news => 1,
                },
				{
                    order_by => 'ctime DESC',
                    rows => 1,
				},
		)->single;
        $blog = $blog->readonly if $blog;
        $battie->to_cache('blog/latest', { blog => $blog }, 60 * 10);
    }
    else {
        $blog = $cached->{blog};
        #$battie->timer_step("blog__show_news cache");
        $self->load_db($battie);
    }
    my $data = $battie->get_data;
    $data->{latest_news} = $blog;
    $data->{blog}->{rss_title} = $self->rss_title;
    #$battie->timer_step("blog__show_news end");
}


sub blog__edit_theme {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->exception("Argument", "Not a valid id") if $id =~ tr/0-9//c;
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    my $schema = $self->get_schema->{blog};
    my $theme_rs = $schema->resultset('Theme');
    my $theme = $theme_rs->find($id);
    $self->exception("Argument", "Theme does not exist") unless $theme;
    $data->{blog}->{theme} = $theme->readonly;
    $data->{blog}->{image_url} = $self->image_url;
    my $blog = $theme->blog;
    $data->{blog}->{blog} = $blog->readonly;
    my $dir = $self->image_dir($battie);
    my @blogs = $schema->resultset('Blog')->search(
            { },
            {
                    order_by => 'title',
            },
    )->all;
    @blogs = map { $_->readonly } @blogs;
    if ($submit->{delete} and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{save} and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{upload} and not $battie->valid_token) {
        $self->exception("Argument", "Your token expired, please try again by going back and reloading the form");
    }
    if ($submit->{upload}) {
        my $file = $request->get_cgi->upload('theme.image');
        warn __PACKAGE__." ============$file\n";
        my $suffix = lc( (split m/\./, $file)[-1] );
        $suffix =~ tr/a-zA-Z0-9_//cd;
        my $tempfile = "/tmp/upload_theme_$id.$suffix";
        my $final = "$dir/theme_$id.$suffix";
        open my $fh, '>', $tempfile or die $!;
        while (<$file>) {
            print $fh $_;
        }
        close $fh;
        warn __PACKAGE__." move $tempfile, $final\n";
        move $tempfile, $final or die $!;
        $theme->image("theme_$id.$suffix");
        $theme->update;
        $battie->writelog($theme, 'upload');
        $battie->delete_cache('blog/latest_news');
        $battie->set_local_redirect('/blog/edit_theme/' . $id);
        return;
    }
    elsif ($submit->{delete}) {
        if ($theme->active) {
            $self->exception("Argument", "Set theme to invisible first");
        }
        my $blog = $theme->blog;
        my $image = $theme->image;
        if ($image) {
            # delete teaser image from filesystem
            my $dir = $self->image_dir($battie);
            my $path = "$dir/$image";
            warn __PACKAGE__.':'.__LINE__.": delete $path\n";
            unlink $path or warn "Could not delete '$path': $!";
        }
        $battie->writelog($theme, 'delete');
        $theme->delete;
        $battie->delete_cache('blog/latest_news');
        $battie->set_local_redirect("/blog/list_blog/" . $blog->id);
        return;
    }
    elsif ($submit->{save}) {
        my $message = $request->param('theme.message');
        my $blog_id = $request->param('theme.blog_id');
        my $abstract = $request->param('theme.abstract');
        my $is_news = $request->param('theme.is_news');
        my $can_comment = $request->param('theme.can_comment');
        my $active = $request->param('theme.active');
        $theme->message($message);
        $theme->blog_id($blog_id) if $blog_id;
        $theme->abstract($abstract);
        $theme->is_news($is_news ? 1 : 0);
        $theme->can_comment($can_comment ? 1 : 0);
        $theme->active($active);
        $theme->update;
        $battie->writelog($theme, 'update');
        $battie->delete_cache('blog/latest_news');
        $battie->set_local_redirect('/blog/edit_theme/' . $id);
        return;
    }
    $data->{blog}->{image_url} = $battie->get_paths->{docurl} . $self->image_url;
    $data->{blog}->{blog_options} = [
        $theme->blog_id, map { [ $_->id, $_->title ] } @blogs
    ];
}

sub blog__create_theme {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($blog_id) = @$args;
    $self->exception("Argument", "Not a valid id") if $blog_id =~ tr/0-9//c;
    my $schema = $self->get_schema->{blog};
    my $blog_rs = $schema->resultset('Blog');
    my $blog = $blog_rs->find($blog_id);
    $self->exception("Argument", "Blog does not exist") unless $blog;
    my $theme_rs = $schema->resultset('Theme');
    my $data = $battie->get_data;
    $data->{blog}->{blog} = $blog->readonly;
    my $submit = $request->get_submit;
    # TODO $battie->valid_token
    if ($submit->{create} or $submit->{__default}) {
        my $title = $request->param('theme.title');
        my $link = $title;
        $link =~ s/[^0-9a-zA-Z]/_/g;
        my $message = $request->param('theme.message');
        my $abstract = $request->param('theme.abstract');
        my $theme;
        if ($abstract) {
            $schema->txn_begin;
            my $blog = $schema->resultset('Blog')->find($blog_id, { 'for' => 'update' });
            unless ($blog) {
                $schema->txn_rollback;
                $self->exception("Argument", "Blog does not exist");
            }
            $theme = $theme_rs->create({
                    title => $title,
                    message => $message,
                    abstract => $abstract,
                    posted_by => $battie->get_session->userid,
                    blog_id => $blog_id,
                    link => $link,
                    ctime => undef,
                });
            $schema->txn_commit;
            $battie->delete_cache('blog/latest_news');

            my $response = $battie->get_response;
            $response->set_redirect($battie->self_url . '/blog/theme/' . $theme->id);
        }
        else {
            $theme = $theme_rs->new({
                    title => $title,
                    blog_id => $blog_id,
                });
        }
        $data->{blog}->{theme} = $theme->readonly;
    }
}

sub blog__theme {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    my $sug = [ {
        url => '/blog/start',
        desc => 'Blog Homepage',
    } ];
    if ($id =~ tr/0-9//c) {
        my $new_id = $id;
        $new_id =~ tr/0-9//cd;
        if (length $new_id) {
            unshift @$sug, {
                url => '/blog/theme/' . $new_id,
                desc => 'Theme ' . $new_id,
            };
        }
        $battie->not_found_exception("Not a valid id '$id'", $sug);
    }
    my $schema = $self->get_schema->{blog};
    my $theme_rs = $schema->resultset('Theme');
    my $theme = $theme_rs->find($id);
    if (not $theme or (not $theme->active and not $battie->get_allow->can_do(blog => 'edit_theme'))) {
        # don't show inactive themes to unauthorized users
        $battie->not_found_exception("Theme '$id' does not exist", $sug);
    }
    my $blog_rs = $schema->resultset('Blog');
    my $blog = $theme->blog;
    $self->exception("Argument", "Blog does not exist") unless $blog;
    my $data = $battie->get_data;
    my $html = $self->render_textile($battie, $theme->message);
    my $html_abstract = $self->render_textile($battie, $theme->abstract);
    $data->{blog}->{blog} = $blog->readonly;
    my $ro = $theme->readonly;
    my $poster = $battie->module_call(login => 'get_user_by_id', $theme->posted_by);
    $ro->set_posted_by_user($poster->readonly);
    $data->{blog}->{theme} = $ro;
    my $user = $battie->module_call(login => 'get_user_by_id', $theme->posted_by);
    #warn __PACKAGE__." user=$user\n";
    my $nick = $user->nick;
    #warn __PACKAGE__." nick=$nick\n";
    $data->{blog}->{theme_posted_by} = $user->nick;
    $data->{blog}->{html} = $html;
    $data->{blog}->{abstract} = $html_abstract;
    $data->{blog}->{image_url} = $battie->get_paths->{docurl} . $self->image_url;
    $data->{subtitle} = $theme->title;
}

sub render_textile {
    my ($self, $battie, $text) = @_;
    my $textile = $battie->new_textile;
    $textile->disable_html(1);
    my $html = $textile->process($text);
    return $html;
}


sub blog__list_blog {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    # SEO: no indexing for blog list (avoid duplicate content)
    $battie->response->set_no_index(1);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id, $search_title) = @$args;
    my $blog;
    my $schema = $self->get_schema->{blog};
    if ($id =~ tr/0-9//c) {
        # search for title
        $search_title = $id;
        $blog = $schema->resultset('Blog')->find({title => $search_title});
        $self->exception("Argument", "Blog '$search_title' does not exist") unless $blog;
        $battie->set_local_redirect("/blog/list_blog/" . $blog->id . '/' . $blog->readonly->url_title);
        return;
    }
    else {
        $blog = $schema->resultset('Blog')->find($id);
        $self->exception("Argument", "Blog $id does not exist") unless $blog;
    }
    my $data = $battie->get_data;
    $data->{blog}->{blog} = $blog->readonly;
    my $theme_rs = $schema->resultset('Theme');
    my $theme_search = $theme_rs->search(
            {
                blog_id => $blog->id,
                $battie->get_allow->can_do(blog => 'edit_theme') ?
                () : (active => 1),
            },
            {
                    order_by => 'ctime desc',
            },
    );
    my @themes;
    while (my $theme = $theme_search->next) {
        my $ro = $theme->readonly;
        my $user = $battie->module_call(login => 'get_user_by_id', $theme->posted_by);
        $ro->set_posted_by_user($user->readonly);
        push @themes, $ro;
    }
    $data->{blog}->{themes} = \@themes;
    $data->{blog}->{image_url} = $battie->get_paths->{docurl} . $self->image_url;
    $data->{subtitle} = 'blog ' . $blog->title;
}

sub blog__start {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    my ($year, $month) = @$args;
    my $schema = $self->get_schema->{blog};
    my $blogs = $self->fetch_blogs($battie);
    my $data = $battie->get_data;
    if ($year) {
        my $calendar = $self->make_calendar($battie, "month", $year, $month);
        $data->{blog}->{calendar} = $calendar;
        my $year_calendar = $self->make_calendar($battie, "year", $year, $month);
        $data->{blog}->{year_calendar} = $year_calendar;
        my $themes = $calendar->{themes};
        # SEO: no indexing for calendar
        $battie->response->set_no_index(1);

        $data->{blog}->{themes} = $themes;
        $data->{subtitle} = "blog $year/$month";
    }
    else {
        # just show recent x themes
        my $news = $self->create_latest_news_list($battie);
        $data->{blog}->{themes} = $news;
        my $first = $news->[0];
        my ($year, $month);
        if ($first) {
            ($year, $month) = $first->ctime =~ m/^(\d{4})-(\d{2})/;
        }
        else {
            ($year, $month) = (localtime)[5,4];
            $year += 1900;
            $month++;
        }
        $data->{blog}->{year} = $year;
        $data->{blog}->{month} = $month;
    }
    $data->{blog}->{list} = $blogs;
    $data->{blog}->{image_url} = $battie->get_paths->{docurl} . $self->image_url;
}

sub fetch_blogs {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{blog};
    my $blogs = $battie->from_cache("blog/categories");
    unless ($blogs) {

        my $blog_rs = $schema->resultset('Blog');
        my $blog_search = $blog_rs->search(
                { },
                {
                        order_by => 'title',
                },
        );
        my @blogs;
        while (my $blog = $blog_search->next) {
                push @blogs, $blog->readonly;
        }
        $blogs = \@blogs;
        $battie->to_cache("blog/categories", $blogs, 60 * 20);
    }
    return $blogs;
}

sub make_calendar {
    my ($self, $battie, $type, $year, $month) = @_;
    my @lt = localtime;
    if (!$year) {
        ($year) = $lt[5];
        $year += 1900;
    }
    if ($year <= 0) {
        ($year) = $lt[5];
        $year += 1900;
    }
    if ($year >= 9999) {
        ($year) = $lt[5];
        $year += 1900;
    }
    if (!$month or $month < 1 or $month > 12) {
        $month = $lt[4];
        $month++;
    }
    if ($type eq 'month') {
        my $calendar = $battie->from_cache("blog/calendar_ym/$year/$month");
        unless ($calendar) {
            $calendar = $self->calendar($battie, $year, $month);
            $self->fill_calendar($battie, $calendar);
            $battie->to_cache("blog/calendar_ym/$year/$month", $calendar, 60);
        }
        $self->filter_calendar($battie, "month", $calendar);
        return $calendar;
    }
    elsif ($type eq 'year') {
        my $calendar = $battie->from_cache("blog/calendar_y/$year");
        unless ($calendar) {
            $calendar = $self->year_calendar($battie, $year, $month);
            $self->fill_year_calendar($battie, $calendar);
            $battie->to_cache("blog/calendar_y/$year", $calendar, 60);
        }
        $calendar->{month} = $month;
        $self->filter_calendar($battie, "year", $calendar);
        return $calendar;
    }
}

sub filter_calendar {
    my ($self, $battie, $type, $calendar) = @_;
    my $can_edit = $battie->get_allow->can_do(blog => 'edit_theme');
    if ($type eq 'year') {
        #current => $month == $_,
        for my $month (@{ $calendar->{months} }) {
            if ($calendar->{month} == $month->{month}) {
                $month->{current} = 1;
            }
        }
        unless ($can_edit) {
            @{ $calendar->{themes} } = grep {
                $_->active
            } @{ $calendar->{themes} };
        }
    }
    elsif ($type eq 'month') {
        unless ($can_edit) {
            @{ $calendar->{themes} } = grep {
                $_->active
            } @{ $calendar->{themes} };
        }
    }
}

sub fill_calendar {
    my ($self, $battie, $calendar) = @_;
    my $start = sprintf "%04d-%02d",
        $calendar->{year}, $calendar->{month};
    my $schema = $self->get_schema->{blog};
    #warn __PACKAGE__.':'.__LINE__.": $start .. $end\n";
    my $search = $schema->resultset('Theme')->search({
            ctime => { 'LIKE' => "$start%" },
            #$battie->get_allow->can_do(blog => 'edit_theme') ?
            #() : (active => 1),
        },
        {
            order_by => 'ctime desc',
        },
    );
    my @themes;
    my %theme_day;
    while (my $theme = $search->next) {
        my $ro = $theme->readonly;
        my $user = $battie->module_call(login => 'get_user_by_id', $theme->posted_by);
        $ro->set_posted_by_user($user->readonly);
        push @themes, $ro;
        my ($day) = $ro->ctime =~ m/^\d{4}-\d{2}-(\d{2})/;
        $theme_day{ $day+0 }++;
    }
    for my $week (@{ $calendar->{days} }) {
        for my $day (@$week) {
            next unless $day;
            $day->{themes} = $theme_day{ $day->{day} };
        }
    }

    # see if something is after and before selected date
    my $count = $schema->resultset('Theme')->count({
        ctime => { '<=' => "$start-00 00:00:00" }
    });
    unless ($count) {
        $calendar->{previous}->{month} = undef;
    }
    my $next_try = sprintf "%04d-%02d",
        $calendar->{next}->{year}, $calendar->{next}->{month};
    $count = $schema->resultset('Theme')->count({
        ctime => { '>=' => "$next_try-01 00:00:00" }
    });
    unless ($count) {
        $calendar->{next}->{month} = undef;
    }
    $count = $schema->resultset('Theme')->count({
        ctime => { '<=' => "$start-01-01 00:00:00" }
    });
    unless ($count) {
        $calendar->{prev_year} = undef;
    }
    $next_try = sprintf "%04d",
        $calendar->{next_year};
    $count = $schema->resultset('Theme')->count({
        ctime => { '>' => "$next_try-01-01 00:00:00" }
    });
    unless ($count) {
        $calendar->{next_year} = undef;
    }

    $calendar->{themes} = \@themes;
}

sub fill_year_calendar {
    my ($self, $battie, $calendar) = @_;
    my $start = sprintf "%04d", $calendar->{year};
    my $schema = $self->get_schema->{blog};
    my $search = $schema->resultset('Theme')->search({
            ctime => { 'LIKE' => "$start%" },
            #$battie->get_allow->can_do(blog => 'edit_theme') ?
            #() : (active => 1),
        },
        {
            order_by => 'ctime desc',
        },
    );
    my @themes;
    my %theme_month;
    while (my $theme = $search->next) {
        my $ro = $theme->readonly;
        my $user = $battie->module_call(login => 'get_user_by_id', $theme->posted_by);
        $ro->set_posted_by_user($user->readonly);
        push @themes, $ro;
        my ($month) = $ro->ctime =~ m/^\d{4}-(\d{2})/;
        $theme_month{ $month+0 }++;
    }
    for my $month (@{ $calendar->{months} }) {
        $month->{themes} = $theme_month{ $month->{month} };
    }
    $calendar->{themes} = \@themes;
}

sub year_calendar {
    my ($self, $battie, $year, $month) = @_;
    my $translation = $battie->translation;
    my @calendar = map {
        +{
            month => $_,
            month_name => $translation->translate("global_month$_"),
        }
    } 1 .. 12;
    return {
        months => \@calendar,
        year => $year,
        next_year => $year + 1,
        prev_year => $year - 1,
    };
}

sub calendar {
    my ($self, $battie, $year, $month) = @_;
    my $days = DateTime->last_day_of_month( year => $year, month => $month)->day;
    my $dow = DateTime->new(year => $year, month => $month, day => 1)->day_of_week;
    my @calendar;
    push @calendar, [
        (undef) x ($dow - 1),
        map {
            +{ day => $_ }
        } 1 .. (7 - $dow + 1)
    ];
    my $start = 7 - $dow + 1;
    my $rest = ($days - 7 - $dow + 1) % 7;
    my $current = 7 - $dow + 2;
    while ($current < $days) {
        push @calendar, [
            map {
                $_ <= $days ? +{ day => $_ } : undef
            } $current .. $current + 6
        ];
        $current += 7;
    }
    my $translation = $battie->translation;
    my @headline = map {
        { day_name => $translation->translate("global_day${_}_short") }
    } 1 .. 7;
    my $cal = {
        days => \@calendar,
        last_day => $days,
        year => $year,
        month => $month,
        headline => \@headline,
        month_name => $translation->translate("global_month$month"),
        next_year => $year + 1,
        prev_year => $year - 1,
        next => {
            $month == 12
                ? ( month => 1, year => $year + 1 )
                : ( month => $month + 1, year => $year )
        },
        previous => {
            $month == 1
                ? ( month => 12, year => $year - 1 )
                : ( month => $month - 1, year => $year )
        },
    };
    return $cal;
}

sub blog__create_blog {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $schema = $self->get_schema->{blog};
    my $blog_rs = $schema->resultset('Blog');
    my $submit = $request->get_submit;
    # TODO $battie->valid_token
    if ($submit->{create} || $submit->{__default}) {
        my $title = $request->param('blog.title');
        $self->exception("Argument", "Not a valid title") unless $schema->valid_title($title);
        my $exists = $blog_rs->find({title => $title});
        $self->exception("Argument", "Title '$title' already exists") if $exists;
        my $blog = $blog_rs->create({
                title => $title,
                created_by => $battie->get_session->userid,
            });
        $battie->writelog($blog);
        $battie->delete_cache('blog/categories');
        $battie->set_local_redirect("/blog/edit_blog/" . $blog->id);
    }
}

sub blog__edit_blog {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    my $schema = $self->get_schema->{blog};
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->exception("Argument", "Not a valid id") if $id =~ tr/0-9//c;
    my $blog = $schema->resultset('Blog')->find($id);
    $self->exception("Argument", "Blog does not exist") unless $blog;
    my $ro = $blog->readonly;
    my $data = $battie->get_data;
    $data->{blog}->{blog} = $ro;
    if ($submit->{save} and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{delete} and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{save}) {
        my $new_title = $request->param('blog.title');
        $self->exception("Argument", "Not a valid title") unless $schema->valid_title($new_title);
        $blog->title($new_title);
        $blog->update;
        $battie->writelog($blog);
        $battie->delete_cache('blog/categories');
        $battie->set_local_redirect("/blog/edit_blog/" . $blog->id);
        return;
    }
    if ($submit->{delete}) {
        my $count = $schema->resultset('Theme')->count({ blog_id => $blog->id });
        if ($count) {
            # there are themes for this blog, only delete empty blogs
            $self->exception("Argument", "Cannot delete, $count existing themes for blog");
        }
        $schema->txn_begin;
        $blog->delete;
        $count = $schema->resultset('Theme')->count({ blog_id => $blog->id }, { 'for' => 'update' });
        if ($count) {
            # there are themes for this blog, only delete empty blogs
            $schema->txn_rollback;
            $self->exception("Argument", "Cannot delete, $count existing themes for blog");
        }
        $schema->txn_commit;
        $battie->delete_cache('blog/categories');
        $battie->set_local_redirect("/blog/start");
        return;
    }
}
1;
