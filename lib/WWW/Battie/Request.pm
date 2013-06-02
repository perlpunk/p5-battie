package WWW::Battie::Request;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/
    cgi page action args submit cookies sid
    docroot if_modified_since language cgi_class path_info
    browser_switch
/);
use WWW::Battie::Session;
use Date::Parse;

sub parse_args {
    my ($self, $cgi) = @_;
    my $pi = $cgi->path_info;
    $pi =~ s#^/##;
    my $sid = 0;
    if ($pi =~ s#^SID(\w+)(/|\z)##) {
        $sid = $1;
    }

    if (my $s = $cgi->param('s')) {
        $sid = $s;
    }
    my $args = $cgi->param('ma');
    unless ($args) {
        $args = $pi;
    }
    my ($page, $action, @args) = split m#/#, $args;
    return ($sid, $page, $action, @args);
}

sub args {
    return wantarray ? @{ $_[0]->get_args } : $_[0]->get_args;
}

sub cookie {
    my ($self, $name) = @_;
    my $cookies = $self->get_cookies;
    my $cookie = $cookies->{$name} or return;
    my @value = $cookie->value;
    return @value;
}

use constant MAX_PAGES => 1_000;
sub pagenum {
    my ($self, $max) = @_;
    my $page = $self->param('p') || 1;
    $page =~ tr/0-9//cd;
    $page ||= 1;
    $max ||= MAX_PAGES;
    if ($page > $max) {
        $page = $max;
    }
    return $page;
}

use Time::HiRes qw(gettimeofday tv_interval);
sub from_cgi {
    #my $start_time = [gettimeofday];
    my ($class, $cgi, %args) = @_;
    my $default_language = $args{default_language};
    #warn __PACKAGE__.$".Data::Dumper->Dump([\%args], ['args']);
#    my $upload_info = $args{upload_info};
    my $self = $class->new({
#            upload_info => $upload_info,
            docroot => $args{docroot},
            cgi_class => $args{cgi_class},
        });
    $cgi ||= $self->get_cgi_class->{cgi}->new();
    my ($sid, $page, $action, @args) = $class->parse_args($cgi);
    $self->set_path_info('/' . join '/', grep defined, $page, $action, @args);
    $self->set_sid($sid);
    unless ($page) {
        my $default_page = $args{default_page};
        my ($default_module, $default_action) = split m#/#, $default_page;
        $page = $default_module;
        $action = $default_action;
    }
    my %submits;
    # only set submit buttons if method is post (security)
    $self->set_cgi($cgi);
    if ($self->is_post) {
        %submits = map {
            if (m/^submit\.(.*?)(?:\.x|\.y)?$/) {
                my $value = $cgi->param($_);
                ($1 => $value)
            }
            else { () }
        } $cgi->param();
        $submits{__default} = 1;
    }
    warn __PACKAGE__.':'.__LINE__.": SUBMIT: @{[ sort keys %submits ]}\n" if keys %submits;
    $self->set_submit(\%submits);
    $self->set_page($page);
    $self->set_action($action);
    $self->set_args(\@args);
    my $cookies = {};
    $cookies = $self->get_cgi_class->{cookie}->fetch;
    #warn Data::Dumper->Dump([\$cookies], ['cookies']);
    $self->set_cookies($cookies);
    if (defined (my $if_mod_since = $ENV{HTTP_IF_MODIFIED_SINCE})) {
        $if_mod_since =~ s/;.*//;
        $if_mod_since = str2time($if_mod_since);
        if (defined $if_mod_since) {
            $self->set_if_modified_since($if_mod_since);
        }
        else {
            warn "Client sent unparseable If-Modified-Since: '$ENV{HTTP_IF_MODIFIED_SINCE}'.\n";
        }
    }
    #my $elapsed = tv_interval ( $start_time );
    #warn __PACKAGE__." request from_cgi() took $elapsed seconds\n";
    my %language_cookie = $self->cookie('battie_prefs_lang');
    my $preferred;
    my @lang;
    #my $test = $cgi->http('Accept');
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$test], ['test']);
    if ($language_cookie{lang}) {
        $preferred = $language_cookie{lang};
    }
    else {
        my $language = $cgi->http('Accept-language') || $default_language;
        @lang = split m/,/, $language;
        # TODO
        #warn __PACKAGE__.':'.__LINE__.": Accept-language: (@lang)\n";
        for my $lang (@lang) {
            my ($l, $weight) = split m/;/, $lang;
            $weight =~ s/^q=// if $weight;
            $lang = [$l, $weight];
        }
        $preferred = shift @lang;
        $preferred = $preferred->[0];
        $preferred =~ tr/-/_/;
    }
    $preferred = {
        de => 'de_DE',
        de_de => 'de_DE',
        en => 'en_US',
        en_gb => 'en_US',
        en_us => 'en_US',
    }->{lc $preferred} || 'en_US';
    $self->set_language([ $preferred, @lang ]);
    my $ua = $ENV{HTTP_USER_AGENT};
    $ua = '' unless defined $ua;
    my $browser_switch = 'other';
    if ($ua =~ m/Opera/) {
        $browser_switch = 'opera';
    }
    elsif ($ua =~ m/Firefox/) {
        $browser_switch = 'firefox';
    }
    elsif ($ua =~ m/MSIE 9\.\d/) {
        $browser_switch = 'msie9';
    }
    elsif ($ua =~ m/MSIE/) {
        $browser_switch = 'msie';
    }
    $self->set_browser_switch($browser_switch);
    return $self;
}

sub param {
    my ($self, @args) = @_;
    if (wantarray) {
        my @ret = map { Encode::decode_utf8($_) } $self->get_cgi->param(@args);
        return @ret;
    }
    return Encode::decode_utf8($self->get_cgi->param(@args));
}
sub request_method {
    my ($self, @args) = @_;
    return $self->get_cgi->request_method(@args);
}
sub is_post {
    my ($self, @args) = @_;
    return lc $self->get_cgi->request_method() eq 'post' ? 1 : 0;
}

sub is_mtime_satisfying {
    my ($self, $mtime) = @_;
    my $since = $self->get_if_modified_since;
    return () unless defined $since;
    unless ($mtime =~ /^\d+\z/) {
#        warn __PACKAGE__.':'.__LINE__.": $mtime\n";
        $mtime = str2time($mtime);
#        warn __PACKAGE__.':'.__LINE__.": $mtime\n";
        #croak 'unparseable mtime' unless defined $mtime;
        return unless defined $mtime;
    }
#    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$since], ['since']);
#    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$mtime], ['mtime']);
    return $mtime <= $since;
}

1;
