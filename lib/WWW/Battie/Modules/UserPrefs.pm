package WWW::Battie::Modules::UserPrefs;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module::Model';
use base 'Class::Accessor::Fast';
use Image::Resize;
use MIME::Lite;
use File::Temp qw/ tempfile /;
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/
theme_url avatar_url avatar_max avatar_max_x avatar_max_y settings
/);
my %functions = (
    functions => {
        userprefs => {
            start                => 1,
            set_password         => 1,
            set_email            => 1,
            avatar               => 1,
            profile              => 1,
            personal_nodelet     => 1,
            init                 => {
                on_run => 1,
            },
            # guests
            set_theme            => 1,
            timezone             => 1,
            set_lang             => 1,
            settings             => 1,
        },
    },
);
sub functions { %functions }

sub default_actions {
    my ($class, $battie) = @_;
    return {
        guest => [qw/ start init set_theme set_lang settings timezone /],
        user => [qw/ set_password set_email avatar profile /],
        initial => [qw/ set_password set_email personal_nodelet /],
        openid => [qw/ personal_nodelet /],
    };
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        return {
            link => ['userprefs', 'start'],
            image => "settings.png",
            text => $battie->translate("userprefs_preferences"),
        };
    };
}

sub model {
    user => 'WWW::Battie::Schema::User',
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    my $avatar_url = $args->{AVATAR_URL} || '';
    my $theme_url = $args->{THEME_URL} || 1;
    my $self = $class->new({
            theme_url => $theme_url,
            avatar_url   => $avatar_url,
            avatar_max   => $args->{AVATAR_MAX} || 3000,
            avatar_max_x => $args->{AVATAR_MAX_X} || 100,
            avatar_max_y => $args->{AVATAR_MAX_Y} || 100,
        });
}

sub get_avatar_url {
    my ($self, $battie) = @_;
    return $battie->get_paths->{docurl} . $self->get('avatar_url');
}

sub get_avatar_dir {
    my ($self, $battie) = @_;
    return $battie->get_paths->{docroot} . $self->get('avatar_url');
}

sub clear {
    my ($self, $battie) = @_;
    $self->set_settings(undef);
}

sub userprefs__init {
    my ($self, $battie) = @_;
    my $url = $self->get_avatar_url($battie);
    my $data = $battie->get_data;
    $data->{userprefs}->{avatar_url} = $url;
    $data->{userprefs}->{avatar_max} = $self->get_avatar_max;
    $data->{userprefs}->{avatar_max_x} = $self->get_avatar_max_x;
    $data->{userprefs}->{avatar_max_y} = $self->get_avatar_max_y;
    $data->{userprefs}->{local_js}->{'userprefs'} = 1;
    my %css_cookie = $battie->request->cookie('battie_prefs_theme');
    $data->{userprefs}->{css} = $css_cookie{css} || '';
    $data->{userprefs}->{theme} = $battie->get_paths->{docurl}
        . $self->get_theme_url . '/' . ($css_cookie{theme} || 'default');
    $data->{userprefs}->{theme_color} = $battie->get_paths->{docurl}
        . $self->get_theme_url . '/' . ($css_cookie{theme} || 'default') . '/color_' . ($css_cookie{color} || 'default');
    my $settings = $self->init_settings($battie);
    if (my $settings_userprefs = $settings->{userprefs}) {
        $data->{settings}->{inline_css} = 1;
        $data->{settings}->{userprefs}->{font_size} ||= $settings_userprefs->{font_size};
        $data->{settings}->{userprefs}->{font_entity} ||= $settings_userprefs->{font_entity};
    }
    my $uid = $battie->get_session->userid;
    if ($uid) {
        my $request = $battie->request;
        my $navi = $battie->response->get_needs_navi;
        if ($navi) {
        if ($request->get_page ne 'userprefs' or $request->get_action ne 'personal_nodelet') {

            my ($nodelet_cached) = $battie->from_cache('userprefs/nodelet/' . $uid);
            my $ro;
            unless ($nodelet_cached) {
                $self->init_db($battie);
                my $schema = $self->schema->{user};
                my $nodelet = $schema->resultset('MyNodelet')->find({
                        user_id => $uid,
                    });
                if ($nodelet) {
                    $ro = $nodelet->readonly;
                    my $re = $battie->get_render->render_message_nodelet($ro->content);
                    $ro->set_rendered($re);
                }
                $nodelet_cached = { nodelet => $ro };
                $battie->to_cache("userprefs/nodelet/$uid", $nodelet_cached, 60 * 60 * 24 * 5);
            }
            $ro ||= $nodelet_cached->{nodelet};
            $data->{userprefs}->{mynodelet} = $ro;
        }
        }
    }
}
sub init_settings {
    my ($self, $battie) = @_;
    my $settings = $self->get_settings;
    if ($settings) {
        return $settings;
    };
    my %settings_cookie = $battie->request->cookie('battie_settings');
    my %settings;
    for my $key (keys %settings_cookie) {
        my $val = $settings_cookie{$key};
        my ($mod, $name) = split m/\./, $key;
        $settings{$mod}->{$name} = $val;
    }
    $self->set_settings(\%settings);
    return \%settings;
}

sub userprefs__start {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $args = $request->get_args;
}

sub userprefs__profile {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    $self->init_db($battie);
    my $userid = $battie->get_session->userid;
    my $schema = $self->get_schema->{user};
    my $rs = $schema->resultset('Profile');
    my $profile = $rs->find({ user_id => $userid});
    unless ($profile) {
        $profile = $schema->resultset('Profile')->create({user_id => $userid});
    }
    my $data = $battie->get_data;
    if ($submit->{save}) {
        $battie->require_token;
    }
    if ($submit->{save}) {
        my $name = $request->param('profile.name');
        my $location = $request->param('profile.location');
        my $signature = $request->param('profile.signature');
        if ($signature and length($signature) > 500) {
            $self->exception("Argument", "Signature should be 500 characters or shorter");
        }
        my $homepage = $request->param('profile.homepage');
        my $birth_year = $request->param('profile.birth_year');
        my $birth_day = $request->param('profile.birth_day');
        my $birth_month = $request->param('profile.birth_month');
        my $foto_url = $request->param('profile.foto_url');
        my $icq = $request->param('profile.icq');
        my $aol = $request->param('profile.aol');
        my $yahoo = $request->param('profile.yahoo');
        my $msn = $request->param('profile.msn');
        my $sex = $request->param('profile.sex');
        my $interests = $request->param('profile.interests');
        my $geo_lat = $request->param('profile.geo_lat');
        my $geo_long = $request->param('profile.geo_long');
        for ($geo_lat, $geo_long) {
            if (m/^(-?\d{1,3})(\.\d{1,5})?\z/) {
                no warnings;
                $_ = "$1$2";
            }
            else {
                $_ ='';
            }
        }
        if ($birth_day and $birth_month) {
            $birth_day = sprintf "%02d%02d", $birth_month, $birth_day;
        }
        else {
            undef $birth_day;
        }
        $profile->name($name);
        $profile->location($location);
        $profile->signature($signature);
        $profile->homepage($homepage);
        $profile->birth_year($birth_year || undef);
        $profile->birth_day($birth_day);
        $profile->foto_url($foto_url);
        $profile->icq($icq);
        $profile->aol($aol);
        $profile->yahoo($yahoo);
        $profile->msn($msn);
        $profile->sex($sex || undef);
        $profile->interests($interests);
        my $geo = ($geo_lat and $geo_long) ? "$geo_lat,$geo_long" : undef;
        { no warnings;
            if ($geo ne $profile->geo) {
                $profile->geo($geo);
                $battie->module_call(member => 'update_worldmap');
            }
        }
        my %to_update = $profile->get_dirty_columns;
        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%to_update], ['to_update']);
        my $updated = $profile->update();
        $battie->set_local_redirect("/userprefs/profile?confirm=1");
        $battie->writelog($profile);
        $battie->delete_cache('poard/user_info/' . $userid);
        return;
    }
    elsif ($request->param('confirm')) {
        $data->{userprefs}->{confirm} = 1;
    }
    else {
        my $geo_lat = $request->param('profile.geo_lat');
        my $geo_long = $request->param('profile.geo_long');
        my $re_sig = $battie->get_render->render_message_html($profile->signature);
        my $ro = $profile->readonly;
        if ($geo_lat and $geo_long) {
            $ro->set_geo(sprintf "%.5f,%.5f", $geo_lat, $geo_long);
        }
        $ro->set_rendered_sig($re_sig);
        my $birth_day = $profile->birth_day;
        my $birth_month = '';
        if ($birth_day) {
            ($birth_month, $birth_day) = unpack "A2A2", $birth_day;
        }
        else {
            $birth_day = 0;
            $birth_month = 0;
        }
        my $year = (localtime)[5];
        if ($ro->sex) {
            $ro->set_sex_label({ f => 'female', m => 'male', t => 'transgender' }->{ $ro->sex });
        }
        $data->{userprefs}->{profile} = $ro;
        $data->{userprefs}->{years} = [$profile->birth_year||'', map { [$_, $_] } 1900..$year+1900];
        $data->{userprefs}->{months} = [$birth_month+0, map { [$_, $_] } 1..12];
        $data->{userprefs}->{days} = [$birth_day+0, map { [$_, $_] } 1..31];
        $data->{userprefs}->{sexes} = [$profile->sex || '',
            ['f', 'female'], ['m', 'male'], ['t', 'transgender'], ['', 'n/a']];
    }
}

sub userprefs__personal_nodelet {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    my $uid = $battie->get_session->userid;
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    my $nodelet = $schema->resultset('MyNodelet')->find({
            user_id => $uid,
        });
    my $data = $battie->get_data;
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    my $ro;
    if ($nodelet) {
        $ro = $nodelet->readonly;
    }
    if (($submit->{add} || $submit->{save}) and not $battie->valid_token) {
        $battie->token_exception;
    }
    my $start_links = '[inv]---nodelet-links-start---[/inv]';
    my $end_links   = '[inv]---nodelet-links-end---[/inv]';
    my $initial = <<"EOM";
$start_links\[list][/list]$end_links
EOM
    my $content = $request->param('nodelet.content');
    $content = '' unless defined $content;
    if (length $content > 1024 * 8) {
        $self->exception("Argument", "Text longer than 8k");
    }
    if ($submit->{add} || $submit->{save}) {
        unless ($nodelet) {
            $nodelet = $schema->resultset('MyNodelet')->find_or_create({
                user_id => $uid,
                is_open => 1,
                content => $initial,
            });
        }
        if ($submit->{add}) {
            my $url = $request->param('nodelet.url');
            my $title = $request->param('nodelet.title');
            $self->exception("Argument", "No URL given") if (!defined $url or !length $url);
            my $content = $nodelet->content;
            unless ($content =~ m/\Q$end_links/) {
                $content .= $initial;
            }
            $title = '' unless defined $title;
            $title = "[noparse]$title\[/noparse]" if $title =~ tr/[//;
            my $self_url = $battie->self_url;
            my $url_tag = length $title
                ? "[battie=$url]$title\[/battie]"
                : "[battie]$url\[/battie]";
            $content =~ s{(\[\/list\]\s*\Q$end_links\E)}
                {[*]$url_tag\n$1};
            $nodelet->update({
                content => $content,
            });
            if ($request->param('is_ajax')) {
                $data->{main_template} = "userprefs/ajax.html";
            }
            $battie->delete_cache('userprefs/nodelet/' . $uid);
        }
        elsif ($submit->{save}) {
            $nodelet->update({
                content => $content,
            });
            $battie->delete_cache('userprefs/nodelet/' . $uid);
            $battie->set_local_redirect("/userprefs/personal_nodelet");
            return;
        }
    }
    elsif ($submit->{preview}) {
        $nodelet = $schema->resultset('MyNodelet')->new({
                user_id => $uid,
                is_open => 1,
                content => $content,
            });
        $ro = $nodelet->readonly;
        my $re = $battie->get_render->render_message_nodelet($ro->content);
        $ro->set_rendered($re);
        $data->{userprefs}->{mynodelet} = $ro;
        return;
    }
    if ($nodelet) {
        $ro = $nodelet->readonly;
        my $re = $battie->get_render->render_message_nodelet($ro->content);
        $ro->set_rendered($re);
        $data->{userprefs}->{mynodelet} = $ro;
    }
}

sub userprefs__set_email {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    my $uid = $battie->get_session->userid;
    my $profile = $schema->resultset('Profile')->find({
            user_id => $uid,
        });
    unless ($profile) {
        $profile = $schema->resultset('Profile')->create({user_id => $uid});
    }
    my $old_email;
    if ($profile->email) {
        $old_email = $profile->email;
    }
    my $profile_ro = $profile->readonly;
    $data->{userprefs}->{user}->{profile} = $profile_ro;
    if ($submit->{save} and not $battie->valid_token) {
        delete $submit->{save};
        $data->{userprefs}->{error}->{token} = 1;
    }
    if ($submit->{save}) {
        my $email1 = $request->param('user.new_email1') || '';
        my $email2 = $request->param('user.new_email2') || '';
        my $pass   = $request->param('user.password');
        my $user = $battie->get_session->get_user;
        my $current = $user->get_password;
        my $crypted = $battie->sub_call(login => 'encrypt', $schema, $pass, $current, $user->nick);
        if ($crypted ne $current) {
            $data->{userprefs}->{error}->{wrong_password} = 1;
            return;
        }
        unless ($email1 eq $email2) {
            $data->{userprefs}->{error}->{emails_dont_match} = 1;
            $data->{userprefs}->{input}->{email1} = $email1;
            return;
        }
        if ($old_email eq $email1) {
            $data->{userprefs}->{error}->{same_email} = 1;
            return;
        }
        my $valid = $schema->valid_email($email1);
        unless ($valid) {
            $data->{userprefs}->{error}->{invalid_email} = 1;
            $data->{userprefs}->{input}->{email1} = $email1;
            return;
        }
        my $token = $schema->new_token;
        my $atoken = $schema->resultset('ActionToken')->create({
                user_id => $uid,
                token   => $token,
                action  => "userprefs/set_email",
                info    => $valid,
                ctime   => undef,
            });
        my $nick = $battie->session->get_user->nick;
        my $url = $battie->self_url;
        my $server = $battie->get_paths->{server};
        my $title = $battie->get_paths->{homepage_title};
        my $body = <<"EOM";
hi $nick!

Please go to
$server$url/login/confirm_email/$uid/$token
to activate your new email address <$valid>.
EOM
        $battie->writelog($battie->session->get_user);
        $battie->send_mail({
            to => $valid,
            subject => "[$title] Email Change",
            body => $body,
        });
        if ($old_email) {
            my $copy = <<"EOM";
Hi $nick!

This is just a confirmation message. You have
requested to change your email
from <$old_email>
to <$valid>. You will get an email to your new
address also with a confirmation link.
EOM
            $battie->send_mail({
                to => $old_email,
                subject => "[$title] Email Change",
                body => $copy,
            });
            warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$body], ['body']);
        }
        $battie->set_local_redirect("/userprefs/set_email?sent_confirmation=1");
    }
    elsif ($request->param('sent_confirmation')) {
        $data->{userprefs}->{sent_confirmation} = 1;
    }
    elsif ($request->param('confirmed')) {
        $data->{userprefs}->{confirmed} = 1;
    }
}

sub userprefs__set_password {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    $battie->response->set_no_cache(1);
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    if ($submit->{save} and not $battie->valid_token) {
        delete $submit->{save};
        $data->{userprefs}->{error}->{token} = 1;
    }
    ACTION: {
        if ($submit->{save}) {
            not $request->is_post and $self->exception("Argument", "Sorry");
            my $old = $request->param('user.old_password');
            my $pass1 = $request->param('user.new_password1');
            my $pass2 = $request->param('user.new_password2');
            my $user = $battie->get_session->get_user;
            my $current = $user->get_password;
            $self->init_db($battie);
            my $schema = $self->schema->{user};
            my $old_crypted = $battie->sub_call(login => 'encrypt', $schema, $old, $current, $user->nick);
            if ($old_crypted ne $current) {
                $data->{userprefs}->{error}->{wrong_password} = 1;
                last ACTION;
            }
            if ($pass1 ne $pass2) {
                $data->{userprefs}->{error}->{new_password_match} = 1;
                last ACTION;
            }
            $battie->module_call(login => 'set_password_for_user', $user->id, $pass1);
            $battie->set_local_redirect("/userprefs/set_password?confirm=1");
            $battie->writelog($user);
            return;
        }
        elsif ($request->param('confirm')) {
            $data->{userprefs}->{confirm} = 1;
        }
        else {
        }
    }
}

sub userprefs__avatar {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    $self->init_db($battie);
    my $userid = $battie->get_session->userid;
    my $schema = $self->get_schema->{user};
    my $rs = $schema->resultset('Profile');
    my $profile = $rs->find({ user_id => $userid});
    unless ($profile) {
        $profile = $schema->resultset('Profile')->create({user_id => $userid});
    }
    my $data = $battie->get_data;
    if ($submit->{upload}) {
        $battie->require_token;
        TRY_UPLOAD: {
            my $upload = $request->get_cgi->upload("profile.avatar");
            my $suffix = lc((split m/\./, $upload)[-1]);
            if ($suffix =~ m/^(gif|png|jpg|jpeg)$/) {
                $suffix = $1;
                my $dir = $self->get_avatar_dir($battie);
                my $md5 = Digest::MD5->new();
                $md5->add($$,time, rand(time));
                #my $userid = $battie->get_session->userid;
                my $digest = $md5->hexdigest();


                my ($ifh, $fname) = tempfile();

                my $bytes = 0;
                local $/ = \1024;
                while (my $line = <$upload>) {
                    my $l = length $line;
                    warn __PACKAGE__.':'.__LINE__.": upload $l\n";
                    print $ifh $line;
                    $bytes += length $line;
                    if ($bytes > $self->get_avatar_max) {
                        $data->{userprefs}->{error}->{avatar_too_big} = 1;
                        close $ifh;
                        unlink $fname;
                        last TRY_UPLOAD;
                    }
                }
                close $ifh;
                my $resize = Image::Resize->new($fname) or die "Could not create Image::Resize of $fname";
                unless ($resize) {
                    unlink $fname;
                    last TRY_UPLOAD;
                }
                my ($x, $y) = ($resize->width, $resize->height);
                my $gd;
                if ($x > $self->get_avatar_max_x or $y > $self->get_avatar_max_y) {
                    $gd = $resize->resize($self->get_avatar_max_x, $self->get_avatar_max_y);
                    $data->{userprefs}->{error}->{avatar_too_big} = 1;
                }
                else {
                    $gd = $resize->gd;
                }
                my $new_fname = "$dir/${userid}_$digest.png";
                open my $fh, '>', $new_fname or die $!;
                binmode $fh;
                print $fh $gd->png;
                close $fh;
                unlink $fname;
                $profile->avatar("$digest.png");
                $profile->update;
                $battie->set_local_redirect("/userprefs/avatar?confirm=upload");
                $battie->writelog($profile);
                $battie->delete_cache('poard/user_info/' . $userid);
                return;
            }
            else {
                $self->exception("Argument", "Not a valid image");
            }
        }
    }
    elsif ($submit->{delete}) {
        $battie->require_token;
        if (my $avatar = $profile->avatar) {
            my $dir = $self->get_avatar_dir($battie);
            my $fname = "$dir/${userid}_$avatar";
            if (-f $fname) {
                unlink $fname;
            }
            $profile->avatar('');
            $profile->update;
            $battie->writelog($profile);
            $battie->delete_cache('poard/user_info/' . $userid);
            $battie->set_local_redirect("/userprefs/avatar?confirm=delete");
            return;
        }
    }
    elsif (my $confirm = $request->param('confirm')) {
        if ($confirm eq 'delete') {
            $data->{userprefs}->{confirm_delete} = 1;
        }
        elsif ($confirm eq 'upload') {
            $data->{userprefs}->{confirm_upload} = 1;
        }
    }
    else {
        if ($profile->avatar) {
            $data->{userprefs}->{profile} = $profile->readonly;
        }
    }
}

sub userprefs__set_lang {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $response = $battie->get_response;
    my $submit = $request->get_submit;
    if ($submit->{save} and not $battie->valid_token) {
        $battie->token_exception;
    }
    my @lang = $battie->module_call(system => 'fetch_languages');
    my @lang_ro = map { $_->readonly } @lang;
    if ($submit->{save}) {
        my $lang = $request->param('prefs.lang');
        unless (grep { $lang eq $_->id } @lang_ro) {
            $self->exception(Argument => 'Language not available');
        }
        $response->add_cookie({
            -name  =>'battie_prefs_lang',
            -value => {
                lang => $lang,
           },
           -expires => '+3M',
        });
        $battie->set_local_redirect("/userprefs/set_lang");
        return;
    }
    my $data = $battie->get_data;
    $data->{userprefs}->{languages} = [$battie->language,
        map { [$_->id, $_->name] } @lang_ro
    ];
    ($data->{userprefs}->{language}) = grep { $battie->language eq $_->id } @lang_ro;

}

my @entities = qw/ pt px em /;
sub userprefs__set_theme {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $response = $battie->get_response;
    my $dir = $battie->get_paths->{docroot} . $self->get_theme_url;
    my @themes = qw/ default /;
    if (-d $dir) {
        opendir my $dh, $dir or die $!;
        while (my $theme = readdir $dh) {
            next if $theme =~ tr/a-zA-Z0-9_-//c or $theme eq 'default';
            push @themes, $theme;
        }
    }

    # read current prefs
    my %css_cookie = $battie->request->cookie('battie_prefs_theme');
    my $current_theme = ($css_cookie{theme} || 'default');
    my $current_color = ($css_cookie{color} || 'default_color');
    unless (grep { $_ eq $current_theme } @themes) {
        $current_theme = 'default';
    }

    my @colors = qw/ default /;
    my $colordir = "$dir/$current_theme";
    if (-d $colordir) {
        opendir my $dh, $colordir or die $!;
        while (my $color = readdir $dh) {
            next if $color =~ tr/a-zA-Z0-9_-//c or $color eq 'color_default';
            $color =~ s/^color_// or next;
            push @colors, $color;
        }
    }

    my $submit = $request->get_submit;
    if ($submit->{save}) {
        $battie->require_token;
        my $theme = $request->param('prefs.theme');
        my $color = $request->param('prefs.color');
        if ($theme and not grep { $_ eq $theme } @themes) {
            $theme = undef;
        }
        if ($color and not grep { $_ eq $color } @colors) {
            $color = undef;
        }
        my $css_url = $request->param('prefs.css_url');
        $css_url = '' if $css_url eq 'http://';
        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$css_url], ['css_url']);
        $response->add_cookie({
            -name => 'battie_prefs_theme',
            -value => {
                $css_url ? (css => $css_url) : (),
                theme => $theme,
                color => $color,
           },
           -expires => '+3M',
        });
        $battie->set_local_redirect("/userprefs/set_theme");
        return;
    }
    my $data    = $battie->get_data;
    $data->{userprefs}->{themes} = [$current_theme || 'default',
        map { [$_, $_] } @themes,
    ];
    $data->{userprefs}->{colors} = [$current_color || 'default',
        map { [$_, $_] } @colors,
    ];
    my $entity = ($self->get_settings || {} )->{userprefs}->{font_entity} || 'px';
    $data->{settings}->{userprefs}->{font_entities} = [
    $entity, @entities
    ];
}

my %defaults = (
    nodelet => {
        hidden  => 0,
    },
);

sub userprefs__timezone {
    my ($self, $battie) = @_;
    my $data = $battie->get_data;
    my $all = DateTime::TimeZone->all_names;
    my $settings = $self->init_settings($battie);
    my $tz;
    if ($settings->{userprefs} and $settings->{userprefs}->{tz}) {
        $tz = $settings->{userprefs}->{tz};
    }
    $data->{userprefs}->{timezones} = [$tz, @$all];
}

sub userprefs__settings {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $args = $request->get_args;
    my ($what) = @$args;
    $what ||= '';
    my $response = $battie->get_response;
    my $submit = $request->get_submit;
    unless ($battie->can_cookie) {
        $battie->cookie_exception;
    }
    if ($submit->{reset} or $submit->{save}) {
        $battie->require_token;
    }
    my $data = $battie->get_data;
    $data->{userprefs}->{setting} = $what;
    if ($what eq 'look') {
        my $settings = $self->init_settings($battie);
        my $cookie_value = $self->settings_to_cookie($settings);
        my $set = 0;
        if ($submit->{save} or $submit->{preview}) {
            my $size = $request->param('settings.font_size');
            $size =~ tr/0-9.//cd;
            $size ||= 12;
            my $entity = $request->param('settings.font_entity');
            ($entity) = grep { $_ eq $entity } @entities;
            my $data    = $battie->get_data;
            $data->{settings}->{userprefs}->{font_size} = $size;
            $data->{settings}->{userprefs}->{font_entity} = $entity;
            $cookie_value->{"userprefs.font_size"} = $size;
            $cookie_value->{"userprefs.font_entity"} = $entity;
            if ($submit->{save}) {
                $set = 1;
                $response->add_cookie({
                    -name  =>'battie_settings',
                    -value => $cookie_value,
                   -expires => '+36M',
                });
                $battie->set_local_redirect("/userprefs/set_theme");
            }
        }
        elsif ($submit->{reset}) {
            $set = 1;
            delete $cookie_value->{"userprefs.font_size"};
            delete $cookie_value->{"userprefs.font_entity"};
            $response->add_cookie({
                -name  =>'battie_settings',
                -value => $cookie_value,
                -expires => '+36M',
            });
            $battie->set_local_redirect("/userprefs/set_theme");
        }
        if ($set) {
            $response->add_cookie({
                -name    =>'battie_font_set',
                -value   => { set => 1 },
                -expires => '+36M',
            });
        }
        return;
    }
    elsif ($what eq 'timezone') {
        my $settings = $self->init_settings($battie);
        if ($submit->{save}) {
            my $tz = $request->param('settings.timezone') || '';
            my $cookie_value = $self->settings_to_cookie($settings);
            $cookie_value->{"userprefs.tz"} = $tz;
            $response->add_cookie({
                -name  =>'battie_settings',
                -value => $cookie_value,
               -expires => '+36M',
            });
            $battie->set_local_redirect("/userprefs/timezone");
        }
    }
    elsif ($what eq 'nodelet') {
        my $profile = $battie->fetch_settings('ro');
        my $settings = $profile ? $profile->meta : {};
        my $set = $settings->{userprefs}->{nodelet} || $defaults{nodelet};
        $data->{settings}->{userprefs}->{nodelet} = $set;
        if ($submit->{save}) {
            my $hide = $request->param('settings.nodelet.hide');
            my $profile = $battie->fetch_settings('rw');
            my $settings = $profile ? $profile->meta : {};
            $settings->{userprefs}->{nodelet} = {
                hidden  => $hide ? 1 : 0,
            };
            # TODO $profile is undef for new users
            $profile->meta($settings);
            $profile->update;
            $battie->set_local_redirect("/userprefs/settings/nodelet");
            $battie->delete_cache('member/settings/' . $battie->session->userid);
            return;
        }
    }
}

sub settings_to_cookie {
    my ($self, $settings) = @_;
    my %cookie_value;
    for my $key (keys %$settings) {
        my $val = $settings->{$key};
        for my $name (keys %$val) {
            $cookie_value{ "$key.$name" } = $val->{$name};
        }
    }
    return \%cookie_value;
}

1;
