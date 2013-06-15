package WWW::Battie;
#$ENV{DBIC_TRACE} = "1=/tmp/mytrace";
#$ENV{DBIC_TRACE} = 1;
use Data::Dumper;
local $Data::Dumper::Indent = 1;
local $Data::Dumper::Sortkeys = 1;
use strict;
use warnings;
our $VERSION = '0.02_005';
use constant TIMER => $ENV{BATTIE_TIMER} || 0;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
my @acc = qw(
    request response data allow session render translation
    language timezone markdown searches
    crumbs logs view https timezone_plugin
    antispam module_navis
);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);
__PACKAGE__->mk_accessors(qw(
    paths conf template errors
    exception db template_param modules on_run module_defs actions
    models layout functions
));
binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';

#use Devel::Peek;
use Hash::Merge qw/ merge /;
use Encode;
use WWW::Battie::Textile;
use Number::Format ();
use Text::Markdown;
use HTML::Template::Compiled;
use WWW::Battie::HTCDateTime;
use HTML::Template::Compiled::Expr;
use HTML::Template::Compiled::Plugin::Translate;
use MIME::Lite;
use HTML::Entities qw(encode_entities);
use WWW::Battie::Request;
use WWW::Battie::Config::Ini;
use WWW::Battie::Response;
use WWW::Battie::Breadcrumb;
#HTML::Template::Compiled->ExpireTime(3);
my $EXPIRE_TIME = 60 * 20;
use WWW::Battie::DBI;
#use CGI::Ajax;
use WWW::Battie::Layout;
use WWW::Battie::Allow;
use WWW::Battie::Render;
use WWW::Battie::Markdown;
use Time::HiRes qw(gettimeofday tv_interval);
use POSIX qw(strftime);
use Fcntl qw(:flock :seek);
our $DEBUG = 0;
my ($debug_time_start, $debug_time_total, $debug_time_current);
#sub set_session {
#    my $start_time = [gettimeofday];
#    my ($self, $value) = @_;
#    warn __PACKAGE__.':'.__LINE__.": set_session\n";
#    $self->{session} = $value;
#    #$self->set(session => $value);
#    my $elapsed = tv_interval ( $start_time );
#    warn __PACKAGE__." set_session() took $elapsed seconds\n";
#}

sub timer_start {
    return unless TIMER;
    my ($self, $msg) = @_;
    my $start = [gettimeofday];
    $debug_time_start = $start;
    $debug_time_current = $start;
    warn "[started timing] $msg\n";
}

sub timer_step {
    return unless TIMER;
    my ($self, $msg) = @_;
    my $e1 = sprintf "%0.6f", tv_interval($debug_time_current);
    my $e2 = tv_interval($debug_time_start);
    $debug_time_current = [gettimeofday];
    warn "[step timing] $msg: $e1 (total $e2)\n";
}

sub template_path {
    my ($self) = @_;
    return $self->get_paths->{templates};
}

sub get_module_list {
    my ($self) = @_;
    my %modules;
    my $functions = $self->get_functions;
    for my $module (keys %$functions) {
        my @actions = keys %{ $functions->{$module}->{actions} };
        @{$modules{$module}}{@actions} = (1) x @actions;
    }
    return \%modules;
}

my %function = (
    functions => {
        start => {
            start => 1,
            error => 1,
        },
    },
);
sub functions { %function }

sub self_url {
    my ($self) = @_;
    my $url = $self->get_paths->{view};
    return $url;
}

sub self_url_w_sid {
    my ($self) = @_;
    my $url = $self->get_paths->{view_w_sid};
    return $url;
}

sub new_textile {
    my ($self) = @_;
    my $curl = $self->sub_call(content => 'get_url');
    my $textile = WWW::Battie::Textile->new(
        self_url => $self->self_url,
        # TODO
        content_url => $self->get_paths->{docurl} . $curl,
    );
    return $textile;
}

sub start__start { }

sub start__error { }

sub from_ini {
    my ($class, $ini, %args) = @_;
    my ($roles);
    my $layout_args = $ini->get_layout;
    my $dsn = $ini->get_db;
    my $antispam = $ini->get_antispam;
    my $dbi = WWW::Battie::DBI->create($dsn);
    my $self = $class->new({
            paths => $ini->get_paths,
            conf => $ini->get_conf,
            data => {},
            errors => {},
            db => $dbi,
            language => 'de_DE',
            antispam => $antispam,
        });
    my $layout = WWW::Battie::Layout->from_ini($self, $layout_args);
    $self->set_layout($layout);
    $self->create_modules(
        module_args => $ini->get_modules,
        model_args => $ini->get_models,
    );
    return $self;
}

sub rerewrite_urls {
    my ($self) = @_;
    $self->get_paths->{view} = $self->get_paths->{view_original};
    $self->get_paths->{view_w_sid} = $self->get_paths->{view_original};
}

sub rewrite_urls {
    my ($self) = @_;
    my $session = $self->get_session;
    my $sid = $session->get_sid;
    return unless $sid;
    my $path_view = $self->get_paths->{view};
    $path_view .= "/SID$sid";
    if (!$session->get_from_cookie) {
        $self->get_paths->{view} = $path_view;
    }
    $self->get_paths->{view_w_sid} = $path_view;
}

sub can_cookie {
    my ($self) = @_;
    my %can_cookie = $self->request->cookie('battie_can_cookie');
    $can_cookie{can}
}

sub output {
    #my $start_time = [gettimeofday];
    my ($self) = @_;
    $self->timer_step("output start");
    my $request = $self->request;
    my $response = $self->get_response;
    my $cgi = $request->get_cgi;
    my $cookie = $response->get_cookie || [];
    #warn Data::Dumper->Dump([\$cookie], ['cookie']);
    #warn Data::Dumper->Dump([\$response], ['response']);
    if (my $redirect = $response->get_redirect) {
        print $cgi->redirect(
            -uri => $redirect,
            @$cookie
            ? (-cookie => [map { $_->as_string } @$cookie])
            : (),
        );
        $self->timer_step("output end (redirect)");
        #my $elapsed = tv_interval ( $start_time );
        #warn __PACKAGE__." output() took $elapsed seconds\n";
        return ('', ":encoding(utf-8)");
    }
    my $status = $response->get_status;
    my $status_code = 200;
    if (defined $status and $status =~ m/^(\d+)/) {
        $status_code = $1;
        $self->logs->{action}->{STATUS} = $status_code;
        if ($status_code == 304) {
            print $cgi->header(
                -charset => 'utf-8',
                -status => $status,
                    @$cookie
                    ? (-cookie => [map { $_->as_string } @$cookie])
                    : (),
            );
            $self->timer_step("output end (304)");
            #my $elapsed = tv_interval ( $start_time );
            #warn __PACKAGE__." output() took $elapsed seconds\n";
            return ('', ":encoding(utf-8)");
        }
    }
    else {
        $self->logs->{action}->{STATUS} = $status_code;
    }
    my $session = $self->get_session;
    #warn Data::Dumper->Dump([\$session], ['session']);
    my $headers = $response->get_header;
    my %additional_headers;
    @additional_headers{map { "-$_" } keys %$headers} = values %$headers;
    my $template = $self->get_template;
    my $header = $cgi->header(
        defined $status ?
        (
            -status => $status
        ) : (),
        $template ? (-charset => 'utf-8') : (),
        -type => $response->get_content_type,
        defined($response->get_expires)
            ? (-expires => $response->get_expires)
            : (),
        ($response->get_no_cache)
            ? (-pragma => 'no-cache')
            : (),
        ($response->get_no_archive)
            ? (-'X-No-Archive' => 'yes')
            : (),
        defined($response->get_last_modified)
            ? (-last_modified => $response->get_last_modified)
            : (),
        @$cookie
            ? (-cookie => [map { $_->as_string } @$cookie])
            : (),
            %additional_headers,
    );
    print $header;

    my $username;
    my $userid = $session->userid;
    if ($userid) {
        my $user = $session->get_user;
        $username = $user ? $user->nick : '';
    }
    my $errors = $self->get_errors;
    my $error = keys %$errors;
    $self->rewrite_urls();
    my $param = $self->get_template_param;
    if ($template) {
        $self->fill_global_template_params($param);
        my $allow = $self->get_allow;
        my ($page, $action) = ($request->get_page, $request->get_action);
        my $request_args = $request->get_args || [];
        $param->{can} = $allow->get_actions;
        $param->{page} = $page;
        $param->{action} = $action;
        $param->{errors} = $errors;
        $param->{error} = $error;
        $param->{sid} = $session->get_sid;
        $param->{response}->{keywords} = $response->get_keywords;
        $param->{request}->{browserswitch} = $request->get_browser_switch;
        my %name_cookie = $request->cookie('battie_remember_name');
        if (defined $name_cookie{login} and length $name_cookie{login}) {
            $param->{username} = $name_cookie{login};
        }
        $param->{ma} = $page . '/' . $action;
        my @current_args = ($page, $action, @$request_args);
        $param->{current_url} = join '/', @current_args;
        if (length $ENV{QUERY_STRING}) {
            $param->{current_url} .= "?$ENV{QUERY_STRING}";
        }
        $param->{seo} = {
            (archive => $response->get_no_archive ? 0 : 1),
            (index => $response->get_no_index ? 0 : 1),
        };

        if (@$request_args) {
            $param->{ma} .= join '/', ('', @$request_args);
        }
        my ($from) = $request->param('login.from');
        $self->get_data->{login}->{from} = $from || $param->{ma};
        $param->{layout} = $self->view;
        $param->{user} = {
            logged_in => $session->userid ? 1 : 0,
            name => $username,
            id  => $userid,
            token => scalar $session->get_token,
        };
        $param->{cookie} = $self->can_cookie ? 1 : 0;
        my $mods = $self->get_modules;
        my $selected;
        my $options = [];
        for my $key (keys %$mods) {
            my $mod = $mods->{ $key };
            if ($mod->isa('WWW::Battie::Module::Search')) {
                my $opts = $mod->search_options($self, $page, $action);
                for my $opt (@$opts) {
                    my ($sel, $id, $label) = @$opt;
                    if ($sel) {
                        $selected = $id;
                    }
                    push @$options, [$id, $label];
                }
            }
        }
        unshift @$options, $selected;

        $param->{data}->{search_options} = $options;

        if ($response->get_needs_navi) {
            $self->create_navigation();
        }
        if (my $e = $self->get_exception) {
            if (ref $e) {
                if ((ref $e) =~ m/^WWW::Battie/) {
                    my $text = $e->text;
                    warn __PACKAGE__.':'.__LINE__.": !!!! $e: $text\n";
                }
                else {
                    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$e], ['e']);
                    $self->get_data->{exception} = $e;
                }
                    $self->get_data->{exception} = $e;
            }
            else {
                warn $e;
                $self->get_data->{exception} = {
                    class => "Unknown",
                    text => "",
                };
            }
        }
        #warn Data::Dumper->Dump([\@modules], ['modules']);
        if ($DEBUG) {
            my $debug = $self->debug_info;
            #warn Data::Dumper->Dump([\$debug], ['debug']);
            $self->get_template_param->{debug} = $debug;
        }
        $self->get_data->{subtitle} ||= $param->{page};
        $template->param( %$param );
        $self->timer_step("before templating");
        my $output = $template->output;
        $self->timer_step("after  templating");
        #Dump $output;
        Encode::_utf8_on($output);
        return ($output, ":encoding(utf-8)");
    }
    else {
        my $output = $response->get_output;
        my $encoding = $response->get_encoding;
        my $mode = $encoding ? ":encoding($encoding)" : ":raw";
        my $l = length $output;
        return $response->get_output, $mode;
    }
    $self->timer_step("output end");
    return '';
}

my $number_format = Number::Format->new(
    -thousands_sep      => ',',
    -decimal_point      => '.',
#    -int_curr_symbol    => "\x{20ac}",
    -kilo_suffix        => 'Kb',
    -mega_suffix        => 'Mb',
);

sub fill_global_template_params {
    my ($self, $param) = @_;
    $param->{timezone} = $self->get_timezone;
    $param->{title} = $self->get_paths->{homepage_title};
    $param->{docurl} = $self->get_paths->{docurl};
    $param->{google_api_key} = $self->get_paths->{google_api_key};
    $param->{now} = time;
    $param->{redir} = $self->get_paths->{redir};
    $param->{server} = $self->get_paths->{server};
    my $url = $self->self_url;
    my $url_sid = $self->self_url_w_sid;
    $param->{self} = $url;
    $param->{self_action} = $url_sid;
    my $data = $self->get_data;
    $data->{userprefs}->{theme} ||= $self->get_paths->{docurl} . $self->get_modules->{userprefs}->get_theme_url . '/default';
    my %css_cookie = $self->request ? $self->request->cookie('battie_prefs_theme') : ();
    if ($css_cookie{css}) {
        $data->{userprefs}->{css_url} = $css_cookie{css};
    }
    my %fontset_cookie = $self->request ? $self->request->cookie('battie_font_set') : ();
    if ($fontset_cookie{set}) {
        $data->{userprefs}->{font_set} = 1;
    }
    $param->{data} = $data;
    $param->{crumbs} = $self->crumbs;
    $param->{number_format} = $number_format;
}

sub create_navigation {
    my ($self) = @_;
    $self->timer_step("create_navigation start");
    my $module_navis = $self->module_navis;
    my $mods = $self->get_modules;
    unless ($module_navis) {
        for my $mod (keys %$mods) {
            my $navi_sub = eval {
                $self->module_call($mod => 'navi');
            } or next;
            $module_navis->{$mod} = $navi_sub;
        }
        $self->set_module_navis($module_navis);
    }
    my $allow = $self->get_allow;
    my $actions = $allow->get_actions;
    my $layout = $self->get_layout;
    my $default = $layout->get_default;
    my @navis;
    my $layout_items = $layout->get_elements;
    my $functions = $self->get_functions;
    my %modules = map { $_ => 1 } keys %$functions;
    my $param = $self->get_template_param;
    my $request = $self->request;
    my $page = $request->get_page;
    my $action = $request->get_action;
    my $url = $self->self_url;
    for my $e (keys %$layout_items) {
        my $order = $layout_items->{$e};
        for my $pos (@$order) {
            if ($pos =~ m/^module:(.*)$/) {
                my $mod = $1;
                next unless $actions->{$mod};
                my $is_active = $page eq $mod;
                push @navis, {
                    type        => 'module',
                    is_active   => $is_active,
                    name        => $mod,
                    slot        => $e,
                };
                delete $modules{$mod};
            }
            elsif ($pos =~ m/^links-(small|big):\(([^\)]+)\)/) {
                my $vh = $1 || 'v';
                my @mods = split /,/, $2;
#                warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@mods], ['mods']);
                my @out;
                for my $mod (@mods) {
                    next unless $actions->{$mod};
                    my $navi_sub = $module_navis->{$mod};
#                    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$navi_sub], ['navi_sub']);
                    my $object = $mods->{$mod};
                    my @links = $navi_sub->($object, $self);
                    for my $link (@links) {
                        my $pa = $link->{link};
                        my $is_active = ($pa and ($pa->[0] eq $page and $pa->[1] eq $action));
                        my $class = '';
                        my $link_class = $link->{link_class};
                        if ($is_active or $link_class) {
                            $class = qq{class="};
                            if ($is_active) {
                                $class .= "active_link ";
                            }
                            if ($link_class) {
                                $class .= $link_class;
                            }
                            $class .= '"';
                        }
                        my $image = '';
                        if ($link->{image}) {
                            my $alt = $link->{alt};
                            $alt = '' unless defined $alt;
                            $image = qq{<img style="vertical-align: bottom;" src="$param->{data}->{userprefs}->{theme}/$link->{image}" alt="$alt">};
                        }
                        my $string = qq{<a $class href="$url/}
                            . join('/', @$pa)
                            . qq{">$image $link->{text}</a>};
                            push @out, $string;
                    }
                    delete $modules{$mod};
                }
                push @navis, {
                    type => 'linklist',
                    list => \@out,
                    slot        => $e,
                    direction => $vh,
                };
            }
            elsif ($pos =~ m/^nodelet:\((.*?)\)$/) {
                my @nodelets = split /,/, $1;
                for my $nodelet (@nodelets) {
                    my ($mod, $action) = split m#/#, $nodelet;
                    next unless $actions->{$mod};
                    next unless $actions->{$mod}->{$action};
                    my $content = $self->module_call($mod => $mod . '__' . $action);
                    push @navis, {
                        type    => 'nodelet',
                        content => $content,
                        slot    => $e,
                        name    => $mod,
                    };
                }
            }
            elsif ($pos =~ m/^nodelet:(\w+)-(.*)$/) {
                my ($mod, $nodelet) = ($1, $2);
                if ($actions->{$mod}->{$nodelet . "_nodelet"}) {
                    push @navis, {
                        type    => 'nodelet',
                        name    => $mod,
                        nodelet => $nodelet,
                        slot    => $e,
                    };
                }
            }
        }
    }
    my @modules = sort keys %modules;
    foreach my $module (@modules) {
        next unless $actions->{$module};
        push @navis, {
            type        => 'module',
            is_active   => $page eq $module,
            name        => $module,
            slot        => $default,
        };
    }

    {
        my $content = $self->create_navi(
            module => $page,
            active => 1,
        );
        $param->{active} = $content;
    }

    for my $navi (@navis) {
        my $slot = $navi->{slot};
        my $mod = $navi->{name},;
        if ($navi->{type} eq 'module') {
            my $content = $self->create_navi(
                module => $mod,
                active => 0,
            );
            push @{ $param->{elements}->{ $slot } }, {
                active  => $navi->{is_active},
                content => $content,
            };
        }
        elsif ($navi->{type} eq 'nodelet') {
            next if $self->view =~ m/small|mini/;
            my $content;
            if ($navi->{nodelet}) {
                $content = $self->create_nodelet(
                    module  => $mod,
                    nodelet => $navi->{nodelet},
                );
            }
            else {
                $content = $navi->{content};
            }
            push @{ $param->{elements}->{ $slot } }, {
                content => $content,
            };
        }
        elsif ($navi->{type} eq 'linklist') {
            my $dir = $navi->{direction};
#            warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$navi], ['navi']);
            if ($dir eq 'small') {
                my $content = qq{<ul>}
                    . (join '', map { "<li>$_</li>" } @{ $navi->{list} })
                    . "</ul>";
                push @{ $param->{elements}->{ $slot } }, {
                    content => $content,
                };
            }
            else {
                for my $l (@{ $navi->{list} } ) {
                    push @{ $param->{elements}->{ $slot } }, {
                        content => $l,
                    };
                }
            }
        }
    }
    $self->timer_step("create_navigation end");
}

sub translate {
    my ($self, $id, $count, $args) = @_;
    my $plug = $self->translation;
    my $translated = $plug->translate($id, $count, $args);
    return $translated;
}

sub init_timezone {
    my ($self, $tz) = @_;
    my $previous = $self->get_timezone;
    if ($previous and $previous eq 'default' and $tz eq 'default') {
        return;
    }
    my $default = $self->get_conf->{timezone};
    my $new;
    if ($tz eq 'default') {
        $new = $default;
    }
    elsif ($previous and $tz eq $previous) {
        return;
    }
    else {
        my $dtz = eval {
            DateTime::TimeZone->new( name => $tz );
        };
        if ($dtz) {
            $new = $tz;
        }
        else {
            $new = $default;
        }
    }
    $self->set_timezone($new);
}

sub init_timezone_translation {
    my ($self, $set_tz, $set_lang) = @_;
    my $request = $self->request;
    my $lang = $set_lang || $request->get_language->[0];
    $self->set_language($lang);
    $self->init_translation($lang);
    my $tz = $set_tz;
    unless ($set_tz) {
        my %settings_cookie = $request->cookie('battie_settings');
        $tz ||= $settings_cookie{"userprefs.tz"} || 'default';
    }
    $tz ||= 'default';
    $self->init_timezone($tz);
    my $plug = $self->timezone_plugin;
    unless ($plug) {
        $plug = WWW::Battie::HTCDateTime->new({
            });
        $self->set_timezone_plugin($plug);
    }
    my $plug_translation = $self->translation;
    $plug->init_request(
        timezone => $self->get_timezone,
        translate => $plug_translation,
    );
    $self->module_call(userprefs => 'clear');
}

sub init_translation {
    my ($self, $lang) = @_;
    my $plug = $self->translation;
    unless ($plug) {
        $plug = HTML::Template::Compiled::Plugin::Translate->new({
            lang => '',
        });
        $self->set_translation($plug);
    }
    $plug = $self->translation;
    if ($plug->lang ne $lang) {
        my $start = [gettimeofday];
        $self->timer_step("before translation");
        my $map = {};
        eval {
            $map = $self->module_call(system => 'fetch_translations', $lang);
        };
        $plug->set_map($map);
        my $el = tv_interval($start);
        warn __PACKAGE__.':'.__LINE__.": language change (@{[ $plug->lang ]} -> $lang) took $el\n";
        $plug->set_lang($lang);
        $self->timer_step("after translation");
    }
}

sub create_htc {
    my ($self, %args) = @_;
    my $cache = $self->get_paths->{template_cache};
#    $self->init_translation();
#    $self->init_timezone('default');
    my $plug = $self->translation;
    my $tz_plug = $self->timezone_plugin;
    my %default = (
        cache => 1,
        debug => 0,
        cache_dir => $cache,
        tagstyle => [qw/ -classic -comment +asp +tt /],
        cache_debug => [qw/ mem_miss file_miss /],
        plugin => [qw(::HTML_Tags WWW::Battie::HtcDhtml ), $plug, $tz_plug],
        use_expressions => 1,
        search_path_on_include => 1,
        loop_context_vars => 1,
        default_escape => 'HTML',
        expire_time => $self->get_conf->{template_expire},
        $self->get_conf->{debug}
            ? (debug_file => 'start,end,short')
            : (),
    );

    my $htc;
    eval {
        $htc = HTML::Template::Compiled->new(
            %default,
            %args,
        );
    };
    warn __PACKAGE__.':'.__LINE__.": error loading template: $@\n" if $@;
    return $htc;
}

sub valid_token {
    my ($self) = @_;
    my $request = $self->request;
    # TODO
    # tokens for guests
    my $session = $self->get_session or return 1;
    my $token = $session->get_token or return 1;
    my $t = $request->param('t') or return 0;
    #warn __PACKAGE__." token $t valid?\n";
    my $id = $token->id or return 0;
    #warn __PACKAGE__." $t eq $id ?\n";
    if ($t eq $id) {
        return 1;
    }
    elsif (my $id2 = $token->id2) {
        return 1 if $id2 eq $t;
    }
    return 0;
}

sub create_navi {
    my ($self, %args) = @_;
    my $mod = $args{module};
    my $active = $args{active};
    my $file;
    if ($active) {
        $file = "$mod/navi_active.html";
    }
    else {
        if ($self->view =~ m/small|mini/) {
            $file = "$mod/navi_small.html";
        }
        else {
            $file = "$mod/navi.html";
        }
    }
    my $htc = $self->create_htc(
        path => $self->template_path,
        filename => $file,
        debug => 0,
    ) or return '';
    $htc->param(%{ $self->get_template_param });
    my $out = $htc->output;
    return $out;
}

sub create_nodelet {
    my ($self, %args) = @_;
    my $mod = $args{module};
    my $nodelet = $args{nodelet};
    my $file = "$mod/$nodelet-nodelet.html";
    my $htc = $self->create_htc(
        path => $self->template_path,
        filename => $file,
        debug => 0,
    ) or return '';
    $htc->param(%{ $self->get_template_param });
    my $out = $htc->output;
    return $out;
}

sub debug_info {
    my ($self) = @_;
    my $request = $self->request;
    my $session = $self->get_session;
    my $username = $session->userid;
    my $s = $session->get_cgis;
    my $times = {};
    my $debug = {};
    my $page = $self->request->get_page;
    my $action = $self->request->get_action;
    $debug->{page} = $page;
    $debug->{action} = $action;
    if (my $e = $self->get_exception) {
        $debug->{exception} = $e;
    }
    if ($s) {
        my $ctime = $s->ctime;
        my $atime = $s->atime;
        my $expire = $s->expire;
        $debug->{session} = {
            ctime => scalar localtime $ctime,
            atime => scalar localtime $atime,
            expire => scalar localtime ($atime + $expire),
        };
    }
    #warn Data::Dumper->Dump([\$s], ['s']);
    my $functions = $self->get_functions;
    my $modules = [map {
        my $actions = $functions->{$_}->{actions};
        my $list = [map {
            +{
                class => $actions->{$_}->{class},
                name => $_,
            }
        } sort keys %$actions];
        +{
            name => $_,
            actions => $list,
        };
    } sort keys %$functions];
    $debug->{modules} = $modules;
    my $user_id = $session->userid;
    my $user_roles = $self->module_call(login => 'get_roles_by_user', $user_id);
    my $roles = $self->module_call(login => 'get_roles_by_ids', map { $_->role_id } @$user_roles);
    my @current_roles = map { $_->name } @$roles;
    @current_roles = ('guest') unless @current_roles;
    $debug->{roles} = \@current_roles;
    return $debug;
}
sub register { }


sub create_modules {
    my ($self, %args) = @_;
    my $module_objects;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%args], ['args']);
    my %func;
    my %on_run;
    my $soptions = [];
    my %module_defs;
    for my $mod (keys %{ $args{module_args} }) {
        my %register = $mod->functions;
        my $func = $register{functions};
        for my $page (keys %{ $func }) {
            $func{$page}->{class} = $mod;
            my $actions = $func->{$page};
            my $default = delete $actions->{_default};
            $func{$page}->{default} = $default || 'start';
            for my $action (keys %{ $actions }) {
                my $value = $actions->{$action};
                $func{$page}->{actions}->{$action} = {
                    class => $mod,
                };
                next unless $value;
                my $sub = $mod->can($page . '__' . $action) or do {
                    carp "$mod tried to register $page/$action but does not "
                    . "define a method ${page}__$action";
                    next;
                };
                $func{$page}->{actions}->{$action}->{code} = $sub;
                if (ref $value) {
                    if ($value->{on_run}) {
                        $func{$page}->{actions}->{$action}->{on_run} = 1;
                        push @{ $on_run{$page} }, $action;
                    }
                    $module_defs{ $page }->{ $action } = $value;
                }
            }
        }
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$mod], ['mod']);
    }
    $self->set_searches($soptions);
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%func], ['func']);
    $self->set_functions(\%func);
    $self->set_on_run(\%on_run);
    $self->set_module_defs(\%module_defs);
    foreach my $module (keys %func) {
        my $info = $func{$module};
        my $class = $info->{class};
        my $object = $class->super_from_ini($self, $args{module_args}->{$class});
        $module_objects->{$module} = $object;
    }
    $self->set_modules($module_objects);
    my %models;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%args], ['args']);
    for my $model (keys %{ $args{model_args} } ) {
        my $prefix = $args{model_args}->{$model}->{TABLE_PREFIX};
        my $handle = $args{model_args}->{$model}->{DBH};
        $models{$model}->{prefix} = $prefix;
        $models{$model}->{handle} = $handle;
    }
    $self->set_models(\%models);
}

sub table_prefix {
    my ($self, $model) = @_;
    my $models = $self->get_models;
    return $models->{$model}->{prefix};
}

sub handle {
    my ($self, $model) = @_;
    my $models = $self->get_models;
    return $models->{$model}->{handle};
}

sub clear {
    my ($self) = @_;
    $self->set_template(undef);
    $self->set_template_param({});
    $self->set_data({});
    $self->set_language('');
    $self->set_logs({});
    $self->set_session(undef);
    $self->set_https(undef);
    $self->set_exception(undef);
    $self->set_crumbs(WWW::Battie::Breadcrumb->new->append('Start', ''));
    $self->rerewrite_urls;
    if ($self->get_render) {
        $self->get_render->get_bbc2html->set_params({});
        $self->get_render->get_bbc2text->set_params({});
    }
}

my $REQUEST_COUNT = 0;
sub run {
    $REQUEST_COUNT++;
    my ($self, %args) = @_;
    $self->timer_step("run start");
    my $cgi_module = $self->get_paths->{cgi_module};
    my ($cgi_class, $cgi_cookie_class, $cgi_util_class)
        = (qw/ CGI CGI::Cookie CGI::Util /);
    if ($cgi_module eq 'CGI::Simple') {
        s/CGI/CGI::Simple/ for ($cgi_class, $cgi_cookie_class, $cgi_util_class);
    }
    my $cgi_classes = {
        cgi    => $cgi_class,
        cookie => $cgi_cookie_class,
        util   => $cgi_util_class,
    };
    my $default_page = $self->get_paths->{default_page};
    my ($request) = WWW::Battie::Request->from_cgi(
        $args{cgi},
        cgi_class => $cgi_classes,
        docroot => $self->get_paths->{docroot},
        default_page => $default_page,
        default_language => 'de_DE',
    );
    $self->set_request($request);
    $self->init_timezone_translation();
    my $response = WWW::Battie::Response->new({
            cookie_path => $self->self_url,
            secure      => $self->https,
            cgi_class   => $cgi_classes,
            no_archive  => 1,
            no_index    => 1,
            needs_navi  => 1,
            header      => {},
            keywords    => $self->get_conf->{keywords},
        });
    $response->set_content_type('text/html');
    $self->set_response($response);

    my $page = $request->get_page;
    my $action = $request->get_action;
    
    my $create_session = 1;
    my $module_defs = $self->get_module_defs;
    if ($module_defs->{ $page } and $module_defs->{ $page }->{ $action }) {
        my $def = $module_defs->{ $page }->{ $action };
        if ($def->{no_session}) {
            $create_session = 0;
        }
    }
    if ($create_session) {
        $self->module_call(login => 'identify_user');
    }
    else {
        $self->module_call(login => 'create_dummy_session');
    }

    my $settings = $self->fetch_settings('cache') || {};
    my $modules = $self->get_modules;
    my $data = $self->get_data;
    for my $mod (keys %$modules) {
        my $module = $modules->{ $mod };
        my $set = $settings->{ $mod } || {};
        my $can = $module->can('settings_defaults');
        if ($can) {
            $set = {
                %{ $module->$can },
                %$set,
            };
        }
        $data->{settings}->{ $mod } = $set;
    }
    my $lt = localtime;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%ENV], ['ENV']);
    { no warnings;
#        print STDERR "\[$lt\] [$$] $page/$action request: $ENV{REQUEST_URI}\n";
        $self->logs->{action}->{REQUEST} = $ENV{REQUEST_URI};
        $self->logs->{action}->{METHOD} = $ENV{REQUEST_METHOD};
        $self->logs->{action}->{PROTOCOL} = $self->https ? 'https' : 'http';
        $self->logs->{action}->{REQUEST_COUNT} = $REQUEST_COUNT;
    }
    unless ($self->get_render) {
        $self->timer_step("before render init");
        my $render = WWW::Battie::Render->init($self);
        $self->set_render($render);
        $self->timer_step("after render init");
    }
    my $markdown = WWW::Battie::Markdown->new({ battie => $self });
    $self->set_markdown($markdown);
    my $session = $self->session;
    #warn __PACKAGE__.':'.__LINE__.": SESSION $session\n";
    my $ua = $ENV{HTTP_USER_AGENT} || '';
    $self->logs->{action}->{UA} = $ua;
    my $nick = $session->user ? $session->user->nick : '';
    $self->logs->{action}->{USER} = $nick;
    $self->logs->{action}->{UID} = $session->user ? $session->user->id : '';
#    print STDERR "\[$lt\] [$$] ($nick) ($ua)\n";
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$session], ['session']);
    my $user_id = $session->userid;
    $self->set_view_template;
    $self->timer_step("before create_from_user");
    my $allow = WWW::Battie::Allow->create_from_user($self, $session->user);
    $self->timer_step("after create_from_user");
    $self->set_allow($allow);
    my $functions = $self->get_functions;
    my $ran = 0;
    my $is_ajax = $request->param('is_ajax');
#    if ($session->userid) {
#        my $terms = $session->terms_to_accept;
#        my $ct = $response->get_content_type;
#        if ($ct eq 'text/html' and keys %$terms) {
#            my ($first) = keys %$terms;
#            if ($page ne 'system' and $page ne 'error') {
#                $self->set_local_redirect("/system/term/$first/"
#                    . DateTime->from_epoch( epoch => $terms->{$first} ));
#            }
#        }
#    }
    my $need_on_run = 1;
    while (!$ran) {
        my $pages = $functions->{$page};
        my $code;
        my $class;
        #warn __PACKAGE__.':'.__LINE__.": =========== $page/$action\n";
        $ran = 1;
        if ($pages) {
            my $function = $pages->{actions}->{$action||''};
            unless ($function) {
                my $default = $pages->{default};
                $action = $default;
                $function = $pages->{actions}->{$default};
                $request->set_args([]);
                $request->set_action($action);
            }
            $code = $function->{code};
            $class = $function->{class};
            #warn __PACKAGE__.':'.__LINE__.": ------------- setting code $page/$action $code $class\n";
        }
        unless ($code) {
            $action ||= '';
            my $exception = WWW::Battie::NotFoundException->new({
                text => "'$page/$action' doesn't exist",
                class => 'NotFound',
            });
            $self->set_exception($exception);
            $self->get_data->{main_template} = undef;
            my $output = "'$page/$action' not found";
            $self->response->set_output($output);
            $self->response->set_needs_navi(0);
            $self->request->set_page('error');
            $self->request->set_action('message');
            $self->response->set_content_type('text/plain');
            $self->response->set_status('404 Not Found');
            $need_on_run = 0;
            $self->module_call(error => 'error__message');
            $ran = 1;
        }
        elsif ( $allow->can_do($page => $action)) {
            # TODO
            if ($is_ajax or $action =~ m/^(?:ajax|popup)/) {
                $self->get_data->{main_template} = "$page/content.html";
                # may be altered by module later
                $response->set_needs_navi(0);
            }
            elsif ($action =~ m/^(?:xml)/) {
                $self->get_data->{main_template} = "$page/content_xml.xml";
            }
            #warn __PACKAGE__." YEP!\n";
            my $module = $self->get_modules->{$page};
            # seo options
            if (my $arch = $module->seo->{archive}) {
                if (ref $arch) {
                    if ($arch->{$action}) {
                        $response->set_no_archive(0);
                    }
                }
                else {
                    $response->set_no_archive(0);
                }
            }
            if (my $index = $module->seo->{index}) {
                if (ref $index) {
                    if ($index->{$action}) {
                        $response->set_no_index(0);
                    }
                }
                else {
                    $response->set_no_index(0);
                }
            }
            my $url = $self->get_paths->{view};
#            my $pjx = new CGI::Ajax(
#                'ajaxshow' => $url,
#            );
#            my $js = $pjx->show_javascript();
#            $self->get_template_param->{ajax} = {
#               js => $js,
#           };
            $self->crumbs->append($module->title, "$page/" . $pages->{default});
            $self->timer_step("before code");
            eval {
                $module->$code($self);
            };
            $ran = 1;
            $self->timer_step("after code");
            if (my $e = $@) {
                $self->set_exception($e);
                #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$e], ['e']);
                if (ref $e eq 'WWW::Battie::TokenException') {
                    my $r = $self->request;
                    $self->set_request($e->get_request);
                    $self->module_call(error => 'error__token');
                    $self->set_request($r);
                    $self->request->set_page('error');
                    $self->request->set_action('token');
                }
                elsif (ref $e eq 'WWW::Battie::CookieException') {
                    my $r = $self->request;
                    $self->set_request($e->get_request);
                    $self->module_call(error => 'error__cookie');
                    $self->set_request($r);
                    $self->request->set_page('error');
                    $self->request->set_action('cookie');
                }
                elsif (ref $e eq 'WWW::Battie::NotFoundException') {
                    $self->request->set_page('error');
                    $self->request->set_action('notfound');
                    $self->response->set_status('404 Not Found');
                    $response->set_no_index(1);
                    $response->set_no_archive(1);
                }
                elsif (ref $e eq 'WWW::Battie::InternalRedirect') {
                    $page = $e->get_page;
                    $action = $e->get_action;
                    if ( $allow->can_do($page => $action)) {
                        $self->request->set_page($page);
                        $self->request->set_action($action);
                        $ran = 0;
                    }
                    $self->set_exception(undef);
                }
                else {
                    $self->module_call(error => 'error__message');
                    $self->request->set_page('error');
                    $self->request->set_action('message');
                }
            }
        }
        else {
            $ran = 1;
            print STDERR "NOPE! $page/$action\n";
            $request->set_page('login');
            my $args = $request->get_args;
            my $argstring = join "/", @$args;
            if ($page eq 'login' and $action =~ m/(forbidden|auth_required)/) {
                croak "Preventing endless loop for login/$1";
            }
            if ($self->session->userid) {
                $request->set_action('forbidden');
                $self->set_local_redirect("/login/forbidden?login.from=$page/$action/$argstring");
            }
            else {
                $request->set_action('auth_required');
                $self->set_local_redirect("/login/auth_required?login.from=$page/$action/$argstring");
            }
        }
    }
    my $on_run = $self->get_on_run;
    if ($need_on_run) {
        $self->timer_step("before on_run");
        for my $key (keys %$on_run) {
            my $actions = $on_run->{$key} || [];
            for my $action (@$actions) {
                if ($allow->can_do($key => $action)) {
                    #warn __PACKAGE__." $key\__$action\n";
                    $self->module_call($key, $key . '__' . $action);
                    $self->timer_step("on_run $key/$action");
                }
            }
        }
        $self->timer_step("after on_run");
    }
    my $t = $self->get_data->{main_template};
    if ($self->get_data->{main_template}) {
        my $templates = $self->template_path;
        my $htc = $self->create_htc(
            global_vars => 0,
            filename => $self->get_data->{main_template},
            path => $templates,
        );
        $self->set_template($htc);
        $self->get_template_param->{templates} = {
            navi => $request->get_page . '/navi.html',
            content => $request->get_page . '/content.html',
        };
    }
    my $p = $request->get_page;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$p], ['p']);
    #print STDERR "========== $page/$action\n";
    #warn Data::Dumper->Dump([\$session], ['session']);
    $self->get_session->create_cookie($response);
    #my @modules = sort keys %INC;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\@modules], ['modules']);
    $self->timer_step("run end");
}

sub set_local_redirect {
    # redirect to ourself
    my ($self, $redirect) = @_;
    my $url = $self->self_url;
    if (length $url and $url !~ m#/\z# and $redirect !~ m{^/}) {
        $url .= '/';
    }
    if (!length $url and $redirect !~ m{^/}) {
        $url = '/';
    }
    $self->response->set_redirect("$url$redirect");
}

sub set_view_template {
    my ($self) = @_;
    my $request = $self->request;
    my $view = $request->param('battie_view') || '';
    my @k = $request->param();
    my $view_temp = $request->param('battie_view_temp') || '';
    $view = $view_temp if $view_temp;
    my $temp = $view_temp ? 1 : 0;
    my $main_view = "full";
    my $response = $self->response;
    if ($view) {
        if ($view eq 'small') {
            $main_view = "small";
        }
        elsif ($view eq 'full') {
            $main_view = "full";
        }
        elsif ($view eq 'mini') {
            $main_view = "mini";
        }
        unless ($temp) {
            $response->add_cookie({
                -name => 'battie_view',
                -value => {
                    view => $main_view,
               },
               -expires => '+3M',
            });
        }
    }
    else {
        my %template_cookie = $request->cookie('battie_view');
        my $value = $template_cookie{view} || '';
        if ($value eq 'small') {
            $main_view = "small";
        }
        elsif ($value eq 'full') {
            $main_view = "full";
        }
        elsif ($value eq 'mini') {
            $main_view = "mini";
        }
    }
    my $main_template = {
        full    => 'main.html',
        small   => 'main_small.html',
        mini    => 'main_small.html',
    }->{$main_view};
    $self->set_view($main_view);
    $self->get_data->{main_template} = $main_template;
}

sub spamcheck {
    my ($self, $name, %args) = @_;
    return 0 unless defined $name;
    my $antispam = $self->antispam;
    my $module = $antispam->{$name} or return 0;
    return $module->check(
        ip => $ENV{REMOTE_ADDR},
        useragent => $ENV{HTTP_USER_AGENT},
        %args,
    );
}

sub log_spam {
    my ($self, %args) = @_;
    local $Data::Dumper::Sortkeys = 1;
    my %spam = (
        ip => $ENV{REMOTE_ADDR},
        useragent => $ENV{HTTP_USER_AGENT},
        date => scalar localtime,
        %args,
    );
    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%spam], ['spam']);
}

sub exception {
    my ($self, $class, $text) = @_;
    my $ref = ref $self;
    croak Exception($class, $text);
}

sub rethrow {
    my ($self, $e) = @_;
    croak $e;
}

sub internal_redirect {
    my ($self, $page, $action) = @_;
    warn __PACKAGE__.':'.__LINE__.": !!!! internal_redirect($page, $action)\n";
    croak WWW::Battie::InternalRedirect->new({
        page => $page,
        action => $action,
    });
}

sub require_token {
    my ($self) = @_;
    if ($self->valid_token) {
        return 1;
    }
    $self->token_exception;
}

sub token_exception {
    warn __PACKAGE__.':'.__LINE__.": ///////////////////////\n";
    my ($self) = @_;
    my $request = $self->request;
    if ($request->param('ajax')) {
        $request->get_cgi->delete('ajax');
        my $main_template = "main_ajax.html";
        $self->get_data->{main_template} = $main_template;
    }
    my $exception = WWW::Battie::TokenException->new({
        request => $request,
        class => 'Token',
    });
    croak $exception;
}

sub cookie_exception {
    my ($self) = @_;
    my $request = $self->request;
    if ($request->param('ajax')) {
        $request->get_cgi->delete('ajax');
        my $main_template = "main_ajax.html";
        $self->get_data->{main_template} = $main_template;
    }
    my $exception = WWW::Battie::CookieException->new({
        request => $request,
        class => 'Token',
    });
    croak $exception;
}

sub not_found_exception {
    my ($self, $text, $suggestions) = @_;
    my $request = $self->request;
    if ($request->param('ajax')) {
        $request->get_cgi->delete('ajax');
        my $main_template = "main_ajax.html";
        $self->get_data->{main_template} = $main_template;
    }
    my $exception = WWW::Battie::NotFoundException->new({
        suggestions => $suggestions,
        text => $text,
        class => 'NotFound',
    });
    croak $exception;
}

sub writelog {
    my ($self, @args) = @_;
    $self->module_call(log => 'writelog', @args);
}

sub get_logs {
    my ($self, @args) = @_;
    $self->module_call(log => 'load_db');
    return $self->module_call(log => 'get_logs', @args) || [];
}

sub module_call {
    my ($self, $module, $method, @args) = @_;
    my $mod = $self->get_modules->{$module};
    #warn __PACKAGE__." =============$module -> $method ($mod)\n";
    return unless $mod;
    my @res = $mod->$method($self, @args);
    return wantarray ? @res : $res[0];
}

# only call sub without $battie as an extra argument
sub sub_call {
    my ($self, $module, $method, @args) = @_;
    my $mod = $self->get_modules->{$module};
    #warn __PACKAGE__." =============$module -> $method ($mod)\n";
    return unless $mod;
    my @res = $mod->$method(@args);
    return wantarray ? @res : $res[0];
}

sub send_mail {
    my ($self, $args) = @_;
    my $email_config = $self->get_paths->{email};
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$email_config], ['email_config']);
    my $type = $email_config->{type};
    my $from = $email_config->{from};
    if ($type eq 'debug') {
        my $logfile = $email_config->{logfile};
        warn __PACKAGE__.':'.__LINE__.": printing to $logfile\n";
        #return unless -w $logfile;
        open my $fh, '>>', $logfile or die $!;
        flock $fh, LOCK_EX;
        my $lt = localtime;
        print $fh <<"EOM";
Date: $lt
To: $args->{to}
From: $from
Subject: $args->{subject}

$args->{body}
----------------------------------------------------------------------
EOM
        close $fh;
        return;
    }
 
    my %h = (
        To => $args->{to},
        From => $from,
        Subject => $args->{subject},
        Data => $args->{body},
    );
    my %d = (
        Debug => 1,
    );
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%h], ['h']);
    warn __PACKAGE__.':'.__LINE__.": sending mail to $args->{to}\n";
    my $msg = MIME::Lite->new(
        %h,
    );
    $msg->send(
        $type eq 'smtp'
        ?  (
            'smtp' => $email_config->{server},
            AuthUser => $email_config->{user},
            AuthPass => $email_config->{password},
        )
        : ('sendmail' => "$email_config->{sendmail} -t -oi -oem"),
        %d,
    );



}

sub to_cache_add {
    my ($self, $key, $value, $exp) = @_;
    $self->module_call(cache => 'cache_add', $key, $value, $exp);
}

sub to_cache {
    my ($self, $key, $value, $exp) = @_;
    $self->module_call(cache => 'cache', $key, $value, $exp);
}

sub from_cache {
    my ($self, @keys) = @_;
    $self->module_call(cache => 'from_cache', @keys);
}

sub delete_cache {
    my ($self, $key) = @_;
    $self->module_call(cache => 'delete_cache', $key);
}

sub fetch_settings {
    my ($self, $rw) = @_;
    my $userid = $self->session->userid or return;
    if ($rw eq 'cache') {
        my $settings = $self->module_call(member => 'fetch_settings', $rw, $userid);
        return $settings;
    }
    my $profile = $self->module_call(member => 'fetch_settings', $rw, $userid)
        or return;
    if ($rw eq 'ro') {
        my $ro = $profile->readonly([qw/ user_id meta /]);
        return $ro;
    }
    elsif ($rw eq 'rw') {
        return $profile;
    }
}

my @fields = qw/
    EPOCH PSIZE_BEFORE PSHARED_BEFORE PSIZE PSHARED EPOCH PID USER UID COOKIE
    IP TIME REQUEST TS UA METHOD PROTOCOL STATUS REQUEST_COUNT
/;
sub print_action_log {
    my ($self, $logs) = @_;
    my $format = $self->get_paths->{actionlog_format};
    $logs ||= $self->logs->{action};
    my $re = join '|', @fields;
    no warnings 'uninitialized';
    $format =~ s!\$($re)\b!
           my $entry = $logs->{$1};
           if ($entry =~ tr/0-9//c) {
               $entry =~ s/"/""/g;
               $entry = qq/"$entry"/;
           }
           $entry!eg;
    return $format;
}

sub Exception {
    my ($class, $text) = @_;
    warn __PACKAGE__." exception $class, $text\n";
    #sleep 1;
#    warn Carp::longmess;
    return WWW::Battie::Exception->new({
            class => $class,
            text => $text,
        });
}
{
package WWW::Battie::Exception;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw(class text));
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(class text));
}

{
package WWW::Battie::TokenException;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw(class request));
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(class request));
}

{
package WWW::Battie::CookieException;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw(class request));
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(class request));
}

{
package WWW::Battie::NotFoundException;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw(class text suggestions));
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(class text suggestions));
}

{
package WWW::Battie::InternalRedirect;
    use base 'Class::Accessor::Fast';
    my @acc = qw/ page action /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);
}


1;
