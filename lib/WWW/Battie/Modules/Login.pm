package WWW::Battie::Modules::Login;
use strict;
use warnings;
use Carp qw(carp croak);
use MIME::Base64 qw/ encode_base64url /;
use URI::Escape qw/ uri_escape /;
use base 'WWW::Battie::Module::Model';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(
    token_expire registration_token_expire email_token_expire password_token_expire
    openid_secret password_encrypt antispam
));
use Date::Parse qw(str2time);
use MIME::Lite;
use DateTime;

my %functions = (
    functions => {
        login => {
            _default      => 'info',
            logout        => 1,
            auth          => 1,
            ajaxshow      => 1,
            show          => 1,
            info          => 1,
            cookietest    => 1,
            forbidden     => 1,
            auth_required => 1,
            register      => 1,
            confirm       => 1,
            confirm_email => 1,
            forgot_pass   => 1,
            auth_openid   => 1,
            conf          => {
                on_run => 1,
            },
        }
    },
);
sub functions { %functions }

sub default_actions {
    #my ($class, $battie) = @_;
    return {
        guest => [qw/ auth ajaxshow show auth_required register confirm forgot_pass forbidden /],
        initial => [qw/ cookietest logout confirm_email info /],
        openid => [qw/ cookietest logout info /],
        user => [qw/ /],
    };
}

sub model {
    userlist => 'WWW::Battie::Model::DBIC::ActiveUsers',
    user => 'WWW::Battie::Schema::User',
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    my $reg_from = $args->{REGISTER_FROM};
    if ($args->{OPENID_SECRET}) {
#        require Net::OpenID::Consumer;
    }
    my $crypt = $args->{PASSWORD_ENCRYPT} || 'crypt_md5';
    my @crypt = split m/,/, $crypt;
    my $self = $class->new({
            # default one day
            token_expire => $args->{TOKEN_EXPIRE} || 60*60*24,
            registration_token_expire => $args->{REGISTRATION_TOKEN_EXPIRE} || 60*60*24,
            email_token_expire => $args->{EMAIL_TOKEN_EXPIRE} || 60*60*24,
            password_token_expire => $args->{PASSWORD_TOKEN_EXPIRE} || 60*60*24,
            openid_secret => $args->{OPENID_SECRET},
            password_encrypt => \@crypt,
            ($args->{ANTISPAM} ? (antispam => $args->{ANTISPAM}) : ()),
        });
}

sub login__conf {
    my ($self, $battie) = @_;
    my $data = $battie->get_data;
    $data->{login}->{can_openid} = $self->get_openid_secret ? 1 : 0;
    my ($bind_cookie) = $battie->request->cookie('battie_bind_to_ip');
    $data->{login}->{bind_to_ip} = $bind_cookie ? 1 : 0;
}

sub identify_user {
    my ($self, $battie) = @_;
    $battie->timer_step("identify_user start");
    my $request = $battie->get_request;
    my $sid = $request->get_sid;
    my $from_cookie = 0;
    my %can_cookie = $request->cookie('battie_can_cookie');
    $battie->logs->{action}->{COOKIE} = $can_cookie{can} ? 1 : 0;
    unless ($can_cookie{can}) {
        $battie->response->add_cookie({
            -name=>'battie_can_cookie',
            -value => { can => 1 },
            -expires => '+12M',
        });
    }
    TRY_COOKIE: {
        my %cookie = $request->cookie('battie_sid') or last TRY_COOKIE;
        my $id = $cookie{id} or last TRY_COOKIE;
        $sid = $id;
        $request->set_sid($sid);
        $from_cookie = 1;
    }

    $self->init_db($battie);
    my %remember = $request->cookie('battie_remember');
    my $digest = $remember{id} || '';
    my ($session, $from_cache);
    if ($sid) {
        ($session, $from_cache) = WWW::Battie::Session->from_sid($sid,
            schema => $self->get_schema->{userlist},
            from_cookie => $from_cookie,
            ip => $ENV{REMOTE_ADDR},
            battie => $battie,
        );
    }
    else {
        # no session cookie yet
        $session = WWW::Battie::Session::Dummy->new;
    }

    $battie->set_session($session);
    $battie->timer_step("after from_sid");

    my $user;
    if ($session->dummy or not $session->userid) {
        # expird or not valid
        # try remember cookie
        unless ($digest) {
            # no session

            if ($session->dummy) {
                unless ($can_cookie{can}) {
                    return;
                }
                # client can cookies

                my $schema = $self->get_schema->{user};
                my $token = $schema->resultset('Token')->new({
                        id => $schema->new_token(),
                        id2 => '',
                    });
                $session = WWW::Battie::Session::Guest->create(
                    schema => $self->get_schema->{userlist},
                    token => $token->id,
                );
                $sid = $session->get_sid;
                warn __PACKAGE__.':'.__LINE__.": guest session $sid\n";
                $session->set_from_cookie(1);
                $from_cookie = 1;
                $session->set_token($token->readonly);
                $battie->set_session($session);
                $request->set_sid($session->get_sid);
            }
        }
        else {
            (my ($uid), $digest) = split m/:/, $digest;
            if ($uid and $digest) {
                warn __PACKAGE__.':'.__LINE__.": REMEMBER! $uid\n";
                $self->init_db($battie);
                my $schema = $self->get_schema->{userlist};
                $user = $self->authenticate_by_cookie($uid, $digest);
                if ($user) {
    #                my $terms_to_accept = $battie->module_call(system => check_terms_to_accept => $user);
                    my ($bind_cookie) = $battie->request->cookie('battie_bind_to_ip');
                    $session = WWW::Battie::Session->create(
                        schema => $schema,
                        userid => $user->get_id,
                        user => $user->readonly([qw/ id nick group_id active password extra_roles /]),
                        $bind_cookie ? (ip => $ENV{REMOTE_ADDR}) : (),
                    );
                    $sid = $session->get_sid;
                    $request->set_sid($session->get_sid);
                    $session->set_from_cookie(1);
                    $from_cookie = 1;
                    $battie->set_session($session);
                    $from_cache = 0;
    #                $session->update_terms(
    #                    schema => $schema,
    #                    terms =>  $terms_to_accept,
    #                );
                }
            }
        }
    }

    if ($session->userid) {

        if ($from_cache) {
        }
        else {
            my $uid = $session->userid;
            my $schema = $self->get_schema->{user};
            my ($user, $token);
            my $user_token = $battie->from_cache("login/user_token/$uid");
            if ($user_token) {
                $user = $user_token->{user};
                $token = $user_token->{token};
            }
            else {
                $user ||= $schema->resultset('User')->find($uid, { select => [qw/ id nick group_id active password extra_roles /] });
                $user = $user->readonly([qw/ id nick group_id active password extra_roles /]);
                $token = $schema->resultset('Token')->find($uid);
                my $expire = $self->get_token_expire;
                my $expire_cache = 60 * 60;
                unless ($token) {
                    warn __PACKAGE__.':'.__LINE__.": CREATE TOKEN\n";
                    $token = $schema->resultset('Token')->create({
                            user_id => $uid,
                            id => $schema->new_token(),
                            id2 => '',
                            ctime => undef,
                        });
                    $expire_cache = $expire / 2;
                }
                elsif ((time - $token->mtime->epoch) > $expire) {
                    warn __PACKAGE__.':'.__LINE__.": TOKEN EXPIRED\n";
                    # token is expired, so set a completely new one
                    $token->id($schema->new_token());
                    $token->id2($token->id);
                    $token->update;
                    $expire_cache = $expire / 2;
                }
                elsif ((time - $token->mtime->epoch) > $expire / 2) {
                    warn __PACKAGE__.':'.__LINE__.": TOKEN HALF EXPIRED\n";
                    # token is half expired. generate a new one and save
                    # the old one
                    $token->id2($token->id);
                    $token->id($schema->new_token());
                    $token->update;
                    $expire_cache = $expire / 2;
                }
                $token = $token->readonly([qw/ id id2 /]);
                $user_token = { user => $user, token => $token };
                $battie->to_cache("login/user_token/$uid", $user_token, $expire_cache);
            }
            $session->set_user($user);
            $session->set_token($token);
            my $ck = "login/session/$sid";
            #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$session], ['session']);
            warn __PACKAGE__.':'.__LINE__.": save session $ck to cache\n";
            $battie->to_cache($ck, $session, 60 * 3);
#            $battie->timer_step("token end");
        }
        $session->set_from_cookie($from_cookie);
#		my $test = $token->readonly;
#		warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$test], ['test']);
    }
    else {
        # guest session
        $session->set_from_cookie($from_cookie);
        if (not $session->dummy and not $from_cache) {
            warn __PACKAGE__.':'.__LINE__.": save guest $session to cache\n";
            my $ck = "login/session/$sid";
            $battie->to_cache($ck, $session, 60 * 3);
        }
    }
#    elsif ($can_cookie{can}) {
#        my $schema = $self->get_schema->{user};
#            if ($session and ref $session eq 'WWW::Battie::Session') {
#                bless $session, 'WWW::Battie::Session::Guest';
#            }
#            else {
#                $session = WWW::Battie::Session::Guest->from_sid($sid,
#                    schema => $self->get_schema->{userlist},
#                    from_cookie => $from_cookie,
#                    ip => $ENV{REMOTE_ADDR},
#                );
#            }
#            if ($session->cgis and my $t = $session->cgis->token) {
#                my $token = $schema->resultset('Token')->new({
#                        id => $t,
#                        id2 => '',
#                    });
#                $session->set_token($token->readonly);
#            }
#        $battie->set_session($session);
#        $request->set_sid($session->get_sid);
#        $session->set_from_cookie(1);
#    }
    $battie->timer_step("identify_user end");
    if ($session->user and !$session->user->active) {
        $session = WWW::Battie::Session::Dummy->new;
        $battie->set_session($session);
    }
}

sub create_dummy_session {
    my ($self, $battie) = @_;
    my $session = WWW::Battie::Session::Dummy->new;
    $battie->set_session($session);
}

sub get_user_nick_by_id {
    my ($self, $battie, $id) = @_;
    my $ck = "login/user_nick/$id";
    my $nick = $battie->from_cache($ck);
    unless (defined $nick) {
        $self->init_db($battie);
        my $schema = $self->get_schema->{user};
        my $user = $schema->resultset('User')->find(
            $id, { select => 'nick' }
        );
        $nick = $user ? $user->nick : "User $id?";
        $battie->to_cache($ck, $nick, 60 * 60 * 24 * 10);
    }
    return $nick;
}

sub get_user_by_id {
    my ($self, $battie, $id, $select) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    if (ref $id && @$id) {
        my @users = $schema->resultset('User')->search({ id => $id })->all;
        return \@users;
    }
    elsif (ref $id) {
        return [];
    }
    else {
        my $user = $schema->resultset('User')->find(
            $id,
            $select ? { select => $select } : (),
        );
        return $user;
    }
}

sub get_userref_by_nick {
    my ($self, $battie, $nick) = @_;
    my $enc = encode_base64url($nick);
    my $ck = "login/user_by_nick/$enc";
    my $userref = $battie->from_cache($ck);
    unless ($userref) {
        $self->init_db($battie);
        my $schema = $self->get_schema->{user};
        my $user = $schema->resultset('User')->find(
            { nick => $nick }, { select => [qw/ id nick /] });
        $userref = $user ? [$user->id, $user->nick] : [0, '?'];
        $battie->to_cache($ck, $userref, 60 * 60 * 24 * 10);
    }
    return $userref;
}

sub get_user_by_nick {
    my ($self, $battie, $nick) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $user = $schema->resultset('User')->find({ nick => $nick });
}

sub get_roles_by_ids {
    my ($self, $battie, @ids) = @_;
    my @ra;
    return \@ra unless @ids;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $rs = $schema->resultset('Role');
    my $search = $rs->search(
        {
            id => { 'IN' => \@ids },
        },
    );
    while (my $ra = $search->next) {
        push @ra, $ra;
    }
    return \@ra;
}

sub get_role_by_type {
    my ($self, $battie, $type) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $rs = $schema->resultset('Role');
    my $role = $rs->search({
            rtype => $type,
        })->single;
    return $role;
}

sub add_role_to_user {
    my ($self, $battie, $user, $role) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    $schema->resultset('UserRole')->find_or_create({
            role_id => $role->id,
            user_id => $user->id,
        });
}

sub get_roles_by_names {
    my ($self, $battie, @ids) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $rs = $schema->resultset('Role');
    my $search = $rs->search(
        {
            name => { 'IN' => \@ids },
        },
    );
    my @ra;
    while (my $ra = $search->next) {
        push @ra, $ra;
    }
    return \@ra;
}

sub get_actions_by_role_ids {
    my ($self, $battie, @ids) = @_;
    my @ra;
    return \@ra unless @ids;
    $self->init_db($battie, 'user');
    my $schema = $self->get_schema->{user};
    my $rs = $schema->resultset('RoleAction');
    my $search = $rs->search(
        {
            role_id => { 'IN' => \@ids },
        },
    );
    while (my $ra = $search->next) {
        push @ra, $ra;
    }
    return \@ra;
}
sub get_actions_by_role_names {
    my ($self, $battie, @ids) = @_;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@ids], ['ids']);
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    #my $rs = $schema->resultset('RoleAction');
    my @ra;
    return \@ra unless @ids;
    my $rs = $schema->resultset('Role');
    my $search = $rs->search(
        {
            name => { 'IN' => \@ids },
        },
    );
    while (my $ra = $search->next) {
        my $test = $ra->actions;
        push @ra, $ra;
    }
    return \@ra;
}

sub set_password_for_user {
    my ($self, $battie, $uid, $pass) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $crypt_methods = $self->get_password_encrypt;
    my $user = $schema->resultset('User')->find($uid);
    my $preference = $crypt_methods->[0];
    my $crypted = $self->encrypt($schema, $pass, undef, $user->nick);
    $user->password($crypted);
    $user->update;
}

sub get_roles_by_user {
    my ($self, $battie, $uid) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $rs = $schema->resultset('UserRole');
    my $search = $rs->search(
        {
            user_id => $uid,
        },
    );
    my @r;
    while (my $role = $search->next) {
        push @r, $role;
    }
    return \@r;
}

sub get_guest_role {
    my ($self, $battie) = @_;
    $self->init_db($battie, 'user');
    my $schema = $self->get_schema->{user};
    my $rs = $schema->resultset('Role');
    my $role = $rs->find(
        {
            rtype => 'guest',
        },
    );
    return $role;
}

sub get_all_roles {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $rs = $schema->resultset('Role');
    my $search = $rs->search();
    my @r;
    while (my $role = $search->next) {
        push @r, $role;
    }
    return @r;
}

sub login__ajaxshow {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my ($from) = $request->param('login.from') || '';
    $battie->get_data->{login}->{from} = $from;
}

sub login__show {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my ($from) = $request->param('login.from') || '';
    $battie->get_data->{login}->{from} = $from;
}

sub login__cookietest {
    my ($self, $battie) = @_;
    $battie->response->set_needs_navi(0);
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my ($from) = $request->param('login.from') || '';
    my $response = $battie->get_response;
    $battie->rewrite_urls;
    $battie->set_local_redirect("$from");
}

sub login__register {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    my $submit = $request->get_submit;
    my $nick = $request->param('user.nick');
    my $email = $request->param('user.email');
    my $pass1 = $request->param('user.password1');
    my $pass2 = $request->param('user.password2');
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    my $data = $battie->get_data;
    my $terms = $battie->module_call(system => 'fetch_active_terms');
    $data->{login}->{antispam} = $self->get_antispam;
    for my $key (keys %$terms) {
        $terms->{$key} = {
            term => $terms->{$key},
            error => 0,
        };
    }
    $data->{login}->{active_terms} = [sort { $a->{term}->id cmp $b->{term}->id } values %$terms];
    $data->{login}->{newuser} = {
        nick => $nick,
        email => $email,
        password => $pass1,
    };
    my $valid;
    if (my $user = $battie->session->get_user) {
        return;
    }
    if ($submit->{register}) {
        if (not length($pass1) or $pass1 ne $pass2) {
            $data->{login}->{error}->{password} = 1;
            delete $data->{login}->{newuser}->{password};
        }
        unless ($nick = $schema->valid_username($nick)) {
            $data->{login}->{error}->{nick} = 1;
        }
        #my $exists = $schema->resultset('User')->find({nick => $nick});
        if ($schema->resultset('User')->find({nick => $nick})) {
            $data->{login}->{error}->{nick_exists} = 1;
            $submit->{preview} = delete $submit->{register};
        }
        if ($schema->resultset('NewUser')->find({nick => $nick})) {
            $data->{login}->{error}->{nick_exists} = 1;
            $submit->{preview} = delete $submit->{register};
        } 
        $valid = $schema->valid_email($email);
        if (not $valid) {
            $data->{login}->{error}->{email} = 1;
        }
        if ($data->{login}->{error}) {
            $submit->{preview} = delete $submit->{register};
        }
        for my $id (keys %$terms) {
            my $start_date = $terms->{$id}->{term}->start_date . '';
            my $test = $request->param("term.$id") || '';
            if ($test ne $start_date) {
                $terms->{$id}->{error} = 1;
                $data->{login}->{error}->{terms} = 1;
                $submit->{preview} = 1;
                delete $submit->{register};
            }
        }
    }
    if ($submit->{register}) {
        if ($self->get_antispam and not $request->param('antispam_ok')) {
            delete $submit->{register};
        }
    }
    if ($submit->{register}) {
        my $is_spam = $battie->spamcheck(
            $self->get_antispam,
            author => $nick,
            email => $valid,
            type => "registration",
        );
        if ($is_spam) {
            $battie->log_spam(
                author => $nick,
                email => $valid,
                type => "registration",
            );
            $data->{login}->{error}->{spam} = 1;
            $submit->{preview} = 1;
            delete $submit->{register};
        }
    }
    my $test = $data->{login}->{error};
    my $title = $battie->get_paths->{homepage_title};
    my $subject = "[$title] Registration";
    if ($submit->{register}) {
        my $crypted = $self->encrypt($schema, $pass1, undef, $nick);
        my ($user, $token, $new_user) = $self->create_initial_user($battie,
            nick    => $nick,
            email   => $valid,
            pass    => $crypted,
            active  => 0,
            terms   => $terms,
        );
        my $new_user_id = $new_user->id;
        my $uid = 0;
#        my $uid = $user->id;
        $battie->writelog($user);
        my $url = $battie->self_url;
        my $server = $battie->get_paths->{server};
        $battie->init_timezone_translation('default', 'de_DE');
        my $htc = $battie->create_htc(
            filename => 'login/registration.txt',
            path => $battie->template_path,
            default_escape => 0,
            debug_file => '',
        );
        my $param = $battie->get_template_param;
        unless ($param) {
            $param = {};
            $battie->set_template_param($param);
        }
        $battie->fill_global_template_params($param);
        $htc->param(
            register => {
                nick        => $nick,
                uid         => $uid,
                token       => $token,
                new_user_id => $new_user_id,
            },
        );
        $htc->param( %$param );
        my $body = $htc->output;
        $battie->send_mail({
            to => $valid,
            subject => $subject,
            body => $body,
        });
        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$body], ['body']);
        $battie->set_local_redirect("/login/register?confirmation=1");
    }
    elsif ($request->param('confirmation')) {
        $data->{login}->{confirmation} = 1;
        $data->{login}->{subject} = $subject;
    }
}

sub create_initial_roles {
    my ($self, $battie, $user, $init_rolename) = @_;
    my $schema = $self->schema->{user};
    my $guest_role = $schema->resultset('Role')->find({rtype => 'guest'});
    if ($guest_role) {
        my $userrole_guest = $schema->resultset('UserRole')->create({
                role_id => $guest_role->id,
                user_id => $user->id,
            });
    }
    my $init_role = $schema->resultset('Role')->find({rtype => $init_rolename});
    if ($init_role) {
        my $userrole_init = $schema->resultset('UserRole')->create({
                role_id => $init_role->id,
                user_id => $user->id,
            });
    }
}

sub create_initial_user {
    my ($self, $battie, %args) = @_;
    my $nick = $args{nick};
    my $openid = $args{openid};
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    my $user;
    my $profile;
    my $uid;
    my $email = $args{email};
    my $pass = $args{pass};
    my $terms = $args{terms} || {};
    my $meta = {
        system => {
            terms => {
                map {
                    $_ => "". $terms->{$_}->{term}->start_date,
                } keys %$terms
            },
        },
    };
    my $token;
    my $new_user;
    eval{ $schema->txn_do(sub {
        if ($openid) {
            $email = '';
            $pass = '';
        }
#        $user = $schema->resultset('User')->create({
#            nick     => $nick,
#            active   => 0,
#            password => $pass,
#            ctime    => undef,
#            openid   => $openid,
#        });
#        $uid = $user->id;
#        $profile = $schema->resultset('Profile')->create({
#            user_id => $uid,
#            email   => $email,
#            ctime   => undef,
#        });
        $token = $schema->new_token;
        $new_user = $schema->resultset('NewUser')->create({
                nick    => $nick,
                email   => $email,
                openid  => $openid,
                token   => $token,
                meta    => $meta,
                password => $pass,
            });
#        my $atoken = $schema->resultset('ActionToken')->create({
#                user_id => $uid,
#                token   => $token,
#                action  => "login/register",
#                ctime   => undef,
#            });
    }) };
    if ($@) {
        warn __PACKAGE__.':'.__LINE__.": TRANSACTION FAILED: $@\n";
        $self->exception("Argument", "Could not create user");
    }
    return ($user, $token, $new_user);
}

sub login__confirm {
    my ($self, $battie) = @_;
    #my $battie = $self->battie;
    my $request = $battie->request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args > 1;
    my ($uid, $token, $new_user_id) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    my $user;
    eval { $schema->txn_do(sub {
        unless ($new_user_id) {
            $self->exception("Argument", "Registration token does not exist or is expired");
        }
        my $new_user = $schema->resultset('NewUser')->find($new_user_id);
        unless ($new_user) {
            $self->exception("Argument", "Registration token does not exist");
        }
        if ($new_user->token ne $token) {
            $self->exception("Argument", "Registration token does not exist or is expired");
        }
        my $seconds = str2time($new_user->ctime);
        if (time > $seconds + $self->get_registration_token_expire) {
            $new_user->delete;
            $self->exception("Argument", "Registration token is expired");
        }
        my $nick = $new_user->nick;
        my $exists = $schema->resultset('User')->find({nick => $nick});
        my $meta = $new_user->meta;
        unless ($exists) {
            $exists = $self->create_user_with_profile($battie, $new_user);
            $uid = $exists->id;
#            $self->create_initial_roles($battie, $exists, 'initial');
        }
        else {
            $uid = $exists->id;
            $self->create_initial_roles($battie, $exists, 'initial');
            $exists->update({ active => 1 });
        }
        my $ok = $battie->module_call(
            system => add_term_user =>
            user_id => $uid,
            terms => $meta->{system}->{terms} );
        $new_user->delete if $new_user->token eq $token;
    }) };
    if (my $e = $@) {
        warn __PACKAGE__.':'.__LINE__.": TRANSACTION FAILED: $e\n";
        $battie->rethrow($e) if (ref $e) =~ m/^WWW::Battie/;
        $self->exception(Unknown => "Could not create user");
    }
    else {
        $battie->writelog($user);
    }
    my $data = $battie->get_data;
    $data->{login}->{confirmation} = 1;
    #$battie->set_local_redirect("/login/show");
}

sub approve_user {
    my ($self, $battie, $user_id) = @_;
    my $user = $self->get_user_by_id($battie, $user_id) or return;
    my $schema = $self->schema->{user};
    my $initial = $schema->resultset('Group')->find({ rtype => 'initial' });
    my $usergroup = $schema->resultset('Group')->find({ rtype => 'user' });
    if ($user->group_id == $initial->id) {
        $user->update({ group_id => $usergroup->id });
        $battie->delete_cache("login/user_token/$user_id");
        return 1;
    }
    return;
}

sub create_user_with_profile {
    my ($self, $battie, $new_user) = @_;
    my $schema = $self->schema->{user};
    my $group = $schema->resultset('Group')->find({ rtype => 'initial' });
    my $user = $schema->resultset('User')->create({
        nick     => $new_user->nick,
        group_id => $group->id,
        active   => 1,
        password => $new_user->password,
        ctime    => undef,
#        openid   => $openid,
    });
    my $uid = $user->id;
    my $profile = $schema->resultset('Profile')->create({
        user_id => $uid,
        email   => $new_user->email,
        ctime   => undef,
    });
    return $user;
}

sub login__confirm_email {
    my ($self, $battie) = @_;
    #my $battie = $self->battie;
    my $request = $battie->request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args > 1;
    my ($uid, $token) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    my $user = $schema->resultset('User')->find($uid);
    $self->exception("Argument", "User does not exist") unless $user;
    my $atoken = $schema->resultset('ActionToken')->find({
            user_id => $uid,
            token   => $token,
            action  => 'userprefs/set_email',
        });
    if ($atoken) {
        my $seconds = str2time($atoken->ctime);
        if (time > $seconds + $self->get_email_token_expire) {
            $atoken->delete;
            undef $atoken;
        }
    }
    $self->exception("Argument", "Email Change token does not exist or is expired") unless $atoken;
    my $new_email = $atoken->info;
    my $profile = $user->profile;
    $profile->email($new_email);
    $profile->update;
    $atoken->delete;
    $battie->set_local_redirect("/userprefs/set_email?confirmed=1");
    $battie->writelog($profile);
}

sub login__auth_required {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my ($from) = $request->param('login.from') || '';
    $battie->get_data->{login}->{from} = $from;
}

sub login__forbidden {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my ($from) = $request->param('login.from') || '';
    $battie->get_data->{login}->{from} = $from;
}

sub login__auth {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $username = $request->param('auth.user');
    my $pass = $request->param('auth.pass');
        not $request->is_post and $self->exception("Argument", "Sorry");
    my $remember = $request->param('auth.remember') || '';
    my $bind_to_ip = $request->param('auth.bind_to_ip') || '';
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$bind_to_ip], ['bind_to_ip']);
    $self->exception("Argument", "Not enough arguments")
        if (not length $username or not length $pass);
    my $schema = $self->get_schema->{user};
    my ($user, $ok) = $self->authenticate($schema, $username, $pass);
    if ($user && $ok) {
        warn __PACKAGE__.':'.__LINE__.": login ok: $user\n";
    }
    elsif ($user) {
    }
    else {
#        warn __PACKAGE__.':'.__LINE__.": no such user $username\n";
    }
    my $response = $battie->get_response;

    if ($user && $ok) {
        my ($from) = $request->param('login.from');
#        my @terms_to_accept = $battie->module_call(system => check_terms_to_accept => $user->id);
#        if (@terms_to_accept) {
#            $from = "/system/term?" . join ';', map { "ta=$_" } @terms_to_accept;
#        }
        my $schema = $self->get_schema->{userlist};
        my $session;
        if (my $sid = $battie->session->sid) {
            $session = $battie->session;
            # already guest session
            $session->update_user(
                schema => $schema,
                userid => $user->get_id,
                user => $user,
                battie => $battie,
            );
        }
        else {
            $session = WWW::Battie::Session->create(
                schema => $self->get_schema->{userlist},
                userid => $user->get_id,
                user => $user,
                $bind_to_ip ? (ip => $ENV{REMOTE_ADDR}) : (),
            );
        }
#        $session->update_terms(
#            schema => $schema,
#            terms =>  $terms_to_accept,
#        );

        if ($remember eq 'auth') {
            my $md5 = Digest::MD5->new();
            my $p = $user->password;
            my $ct = $user->ctime;
            $md5->add($p,$ct);
            my $digest = $md5->hexdigest();
#            warn __PACKAGE__." remember: $p $ct ($digest)\n";
            my $string = $user->id . ':' . $digest;
            $battie->response->add_cookie({
                -name=>'battie_remember',
                -value => {
                    id => $string,
               },
               -expires => '+2M',
            });
            $battie->writelog($user, "remember");
        }
        elsif ($remember eq 'name') {
            # only remember the login name
            $battie->response->add_cookie({
                -name=>'battie_remember_name',
                -value => {
                    login => $user->nick,
               },
               -expires => '+2M',
            });
            $battie->writelog($user, "remember name");
        }
        elsif ($remember eq 'none') {
            my $cookie = $battie->response->add_cookie({
                -name=>'battie_remember_name',
                -value => {
                    login => '',
               },
               -expires => '-2M',
            });
            my $cookie2 = $battie->response->add_cookie({
                -name=>'battie_remember',
                -value => {
                    id => '',
               },
               -expires => '-2M',
            });
            $battie->writelog($user);
        }
        else {
            $battie->writelog($user);
        }
        warn __PACKAGE__.':'.__LINE__.": setup session $user\n";
        $self->setup_session($battie, $session);
        $battie->rewrite_urls;
        $from = uri_escape($from);
        $battie->set_local_redirect("/login/cookietest?login.from=$from");
        return;
    }
    elsif ($user) {
        $battie->writelog(undef, "authentication failed for '$username'");
    }
    else {
        warn __PACKAGE__.':'.__LINE__.": no such user $username\n";
    }
    my $data = $battie->get_data;
    $data->{login}->{error}->{login_failed} = 1;
}

sub setup_session {
    my ($self, $battie, $session) = @_;
    my $response = $battie->response;
    my $request = $battie->request;
    my $user = $session->user;

    $battie->set_session($session);
    $battie->get_session->create_cookie($response);
    my $s = $session->get_cgis;
    #warn Data::Dumper->Dump([\$s], ['s']);
    my $sid = $s->id;
    #print STDERR "sid: $sid ($username)\n";
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$user], ['user']);
    $battie->module_call(activeusers => 'update_userlist', $user, 'new') if $user->id;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$user], ['user']);
}

sub login__info {
}

sub login__auth_openid {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my $response = $battie->get_response;
    my $submit = $request->get_submit;
  
    my ($from) = $request->param('login.from');
    my $bind_to_ip = $request->param('auth.bind_to_ip') || '';

    my $server = $battie->get_paths->{server};
    # TODO terms
    if ($submit->{auth}) {
        my $lj_id = $request->param('auth.openid.livejournal');
        my $myo_id = $request->param('auth.openid.myopenid');
        my $openid_type;
        my $id;
        if ($lj_id) {
            $openid_type = 'livejournal.com';
            $id = $lj_id;
        }
        elsif ($myo_id) {
            $openid_type = 'myopenid.com';
            $id = $myo_id;
        }
            #    ua    => LWPx::ParanoidAgent->new,
            #    cache => Some::Cache->new,
        if ($id =~ m/^[0-9a-zA-Z_-]+\z/) {
            if ($lj_id) {
                $id = "http://$id.livejournal.com/";
            }
            elsif ($myo_id) {
                $id = "http://$id.myopenid.com/";
            }
            my $csr = Net::OpenID::Consumer->new(
                args  => $request->get_cgi,
                consumer_secret => $self->get_openid_secret,
                required_root => "$server/",
            );
            #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$csr], ['csr']);
            my $url = $battie->self_url;
            my $claimed_identity = $csr->claimed_identity($id);
            #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$claimed_identity], ['claimed_identity']);
            my $check_url = $claimed_identity->check_url(
                return_to  => "$server$url/login/auth_openid?openid.return=1;login.from=$from",
                trust_root => "$server/",
            );
            warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$check_url], ['check_url']);
            $battie->response->set_redirect($check_url);
        }
        else {
            $self->exception("Argument", "Not a valid openid '$id'");
        }
    }
    elsif ($request->param('openid.return')) {
        my $csr = Net::OpenID::Consumer->new(
            args  => $request->get_cgi,
            consumer_secret => $self->get_openid_secret,
            required_root => "$server/",
        );
        warn __PACKAGE__.':'.__LINE__.": returned!!!!\n";
        if (my $setup_url = $csr->user_setup_url) {
            # redirect/link/popup user to $setup_url
            warn __PACKAGE__.':'.__LINE__.": redirect $setup_url\n";
            $battie->response->set_redirect($setup_url);
        }
        elsif ($csr->user_cancel) {
            # restore web app state to prior to check_url
            warn __PACKAGE__.':'.__LINE__.": restore\n";
        }
        elsif (my $vident = $csr->verified_identity) {
            my $verified_url = $vident->url;
            warn __PACKAGE__.':'.__LINE__.": verified! $verified_url\n";
            #print "You are $verified_url !";
            $self->init_db($battie);
            my $schema = $self->schema->{user};
            $schema->txn_begin;
            my ($user, $token);
            eval {
                my $exists = $schema->resultset('User')->find(
                    { nick => $verified_url },
                    { for => 'update' },
                );
                if ($exists) {
                    $user = $exists;
                }
                else {
                    my $type;
                    if ($verified_url =~ m{livejournal.com/\z}) {
                        $type = 'livejournal.com';
                    }
                    elsif ($verified_url =~ m{openid.com}) {
                        $type = 'myopenid.com';
                    }
                    ($user, $token) = $self->create_initial_user($battie,
                        nick => $verified_url,
                        openid => $type,
                    );
                    $user->update({ active => 1 });
                    $self->create_initial_roles($battie, $user, 'openid');
                }
            };
            if ($@) {
                $schema->txn_rollback;
            }
            else {
                $schema->txn_commit;
            }

            my $schema_l = $self->get_schema->{userlist};
            my $session = WWW::Battie::Session->create(
                schema => $self->get_schema->{userlist},
                userid => $user->get_id,
                user => $user,
                $bind_to_ip ? (ip => $ENV{REMOTE_ADDR}) : (),
            );
            warn __PACKAGE__.':'.__LINE__.": setup session\n";
            $self->setup_session($battie, $session);
            $battie->rewrite_urls;
            #my $from = 'login/info';
            $battie->set_local_redirect("/login/cookietest?login.from=$from");
        }
        else {
            warn __PACKAGE__.':'.__LINE__.": invalid!!\n";
            #die "Error validating identity: " . $csr->err;
        }
    }
    else {
    }
}

sub login__logout {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $response = $battie->get_response;
    my $session = $battie->get_session;
    my $u = $session->get_user;
    my $submit = $request->get_submit;
    if ($submit->{logout} and not $battie->valid_token) {
        delete $submit->{logout};
        $battie->get_data->{login}->{error}->{token} = 1;
    }
    if ($submit->{logout}) {
        if (my $user = $session->get_user) {
            $battie->writelog($user);
            $battie->module_call(activeusers => 'update_userlist', $user, 'delete');
            $session->expire_session($response, schema => $self->get_schema->{userlist});
            my $sid = $session->get_sid;
            my $ck = "login/session/$sid";
            $battie->delete_cache($ck);
            $battie->writelog($user);
        }
        $battie->response->add_cookie({
            -name=>'battie_remember',
            -value => {
                id => '',
           },
           -expires => '-2M',
        });
        $battie->set_local_redirect(""); # go to default page
        return;
    }
}

sub login__forgot_pass {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $response = $battie->get_response;
    my $session = $battie->get_session;
    my $u = $session->get_user;
    my $submit = $request->get_submit;
    my $schema = $self->schema->{user};
    my $data = $battie->get_data;
    my $args = $request->get_args;
    my ($ruid, $rtoken);
    if (my $user = $battie->session->get_user) {
        return;
    }
    if (@$args > 1) {
        ($ruid, $rtoken) = @$args;
        if ($ruid =~ tr/0-9//c or $rtoken =~ tr/0-9a-z//c) {
            $ruid = $rtoken = '';
        }
    }
    if ($submit->{send_pass}) {
        my $user;
        my $email;
        my $username = $request->param('username');
        my $remail = $request->param('email');
        if (defined $username and length $username) {
            $user = $schema->resultset('User')
                ->search({ nick => $username, active => 1 }, { rows => 1 })->single;
            if ($user) {
                my $profile = $schema->resultset('Profile')->find( { user_id => $user->id } );
                $email = $profile->email if $profile;
            }
        }
        elsif ($remail) {
            my $profile = $schema->resultset('Profile')->find( { email => $remail } );
            if ($profile) {
                my $user_id = $profile->user_id;
                $user = $schema->resultset('User')
                    ->search({ id => $user_id, active => 1 }, { rows => 1 })->single;
                $email = $profile->email;
            }
        }
        if ($user && not $email) {
            $data->{login}->{error}->{no_email} = 1;
        }
        elsif ($user) {
            my $uid = $user->id;

            my $token = $schema->new_token;
            my $atoken = $schema->resultset('ActionToken')->create({
                    user_id => $uid,
                    token   => $token,
                    action  => "login/forgot_pass",
                    info    => '',
                    ctime   => undef,
                });


            my $nick = $user->nick;
            my $url = $battie->self_url;
            my $server = $battie->get_paths->{server};
            my $title = $battie->get_paths->{homepage_title};
            my $body = <<"EOM";
Hi $nick!

You (or somebody else with the ip $ENV{REMOTE_ADDR}) requested to reset your
password.

Please go to
$server$url/login/forgot_pass/$uid/$token

There you enter your username or your email-address and the new
password.

If you didn't request this, somebody else probably just mistyped their nickname;
you don't need to do anything; your old password will still work.
EOM
            $battie->writelog($battie->session->get_user);
            $battie->send_mail({
                to => $email,
                subject => "[$title] Password Change",
                body => $body,
            });

            warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$body], ['body']);
            $battie->set_local_redirect("/login/forgot_pass?sent_confirmation=1");
        }
        elsif (length $username and !$remail and !$user) {
            # No user found to username
            $data->{login}->{error}->{no_user_found} = 1;
        }
        else {
            # just pretend we sent an email
            # guest users should not find out if an account exists or not this way
            $battie->set_local_redirect("/login/forgot_pass?sent_confirmation=1");
        }
    }
    elsif ($request->param('sent_confirmation')) {
        # user clicked to send an email; just show confirmation
        $data->{login}->{sent_confirmation} = 1;
    }
    elsif ($ruid and $rtoken) {
        # user clicked on link in email or on "Change" in new-password form
        my $atoken = $schema->resultset('ActionToken')->find({
                user_id => $ruid,
                token   => $rtoken,
                action  => "login/forgot_pass",
            });
        if ($atoken) {
            my $seconds = str2time($atoken->ctime);
            if (time > $seconds + $self->get_password_token_expire) {
                $atoken->delete;
                undef $atoken;
            }
        }
        $data->{login}->{change_pass} = 1;
        unless ($atoken) {
            $data->{login}->{error_no_token} = 1;
            return;
        }
        if ($submit->{change}) {
            # user clicked on change, now change the password
            my $user = $schema->resultset('User')->find( { id => $ruid } );
            my $profile = $schema->resultset('Profile')->find( { user_id => $ruid } );
            my $remail = $request->param('email');
            my $username = $request->param('username');
            my $correct = 0;
            # just check if the user knows their email or username
            if (defined $remail and length $remail) {
                $correct = 1 if $remail eq $profile->email;
            }
            elsif (defined $username and length $username) {
                $correct = 1 if $username eq $user->nick;
            }
            $data->{login}->{error}->{wrong_email_or_nick} = 1 unless $correct;
            my $password_match = 0;
            my $pass1 = $request->param('password1');
            my $pass2 = $request->param('password2');
            !defined $_ and $_ = '' for $pass1, $pass2;
            $password_match = 1 if (length $pass1 and $pass1 eq $pass2);
            $data->{login}->{error}->{new_password_match} = 1 unless $password_match;
            if ($correct and $password_match) {
                $battie->set_local_redirect("/login/forgot_pass?changed_pass=1");
                $battie->module_call(login => 'set_password_for_user', $user->id, $pass1);
                $atoken->delete;
                $battie->writelog($user);
                return;
            }
        }
        $data->{login}->{token} = "$ruid/$rtoken";
    }
    elsif ($request->param('changed_pass')) {
        # finished; just show confirmation
        $data->{login}->{changed_pass} = 1;
    }
}

sub encrypt {
    my ($self, $schema, $pass, $crypted, $nick) = @_;
    my $crypt_methods = $self->get_password_encrypt;
    my $preference = $crypt_methods->[0];
    if ($crypted) {
        if ($crypted =~ m/^\$1\$[A-Za-z0-9]{1,8}\$/) {
            $preference = 'crypt_md5';
        }
        elsif (length $crypted == 32) {
            $preference = 'md5_username';
        }
        elsif (length $crypted == 13) {
            $preference = 'crypt';
        }
    }
    my $new;
    if ($preference eq 'crypt') {
        $new = $schema->encrypt($pass, $crypted);
    }
    elsif ($preference eq 'crypt_md5') {
        $new = $schema->encrypt_md5($pass, $crypted);
    }
    elsif ($preference eq 'md5_username') {
        $new = $schema->encrypt_md5_username($pass, $crypted, $nick);
    }
    else {
        croak "Crypt method '$preference' is invalid, must be crypt, crypt_md5, md5_username";
    }
    return $new;

}

sub compare {
    my ($self, $schema, $name, $pass) = @_;
    my $rs = $schema->resultset('User');
    my $user = $rs->find( { nick => $name } ) or return;
    return unless $user->active;
    my $user_pass = $user->get_password or return;
    defined(my $crypted = $user_pass) or return;
    my $test = $self->encrypt($schema, $pass, $crypted, $user->nick);
    #print STDERR "$test eq $crypted?\n";
    if ($test eq $crypted) {
        return ($user, 1);
    }
    return ($user, 0);
}

sub authenticate_by_cookie {
    my ($self, $uid, $digest) = @_;
    my $schema = $self->get_schema->{user};
    my $rs = $schema->resultset('User');
    my $user = $rs->find($uid, { select => [qw/ id nick group_id active password extra_roles ctime /] }) or return;
    return unless $user->active;
    my $md5 = Digest::MD5->new();
    my $p = $user->password;
    my $ct = $user->ctime;
    $md5->add($p,$ct);
    my $real_digest = $md5->hexdigest();
    if ($digest eq $real_digest) {
        $user->lastlogin(DateTime->now);
        $user->update;
        return $user;
    }
    return;
}

sub authenticate {
    my ($self, $schema, $name, $pass) = @_;
    my ($user, $ok) = $self->compare($schema, $name, $pass);
    if ($user) {
        $user->lastlogin(DateTime->now);
        $user->update;
        my $ro = $user->readonly([qw/ id active nick password ctime mtime lastlogin openid /]);
        return ($ro, $ok);
    }
    return;
}

sub clean_expired_sessions {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{userlist};
    my $minus = time - 60 * 60 * 2;
    my $search = $schema->resultset('Session')->search(
        {
             mtime => { '<' , $minus },
        },
    );
    my $count = $search->delete;
    return $count;
}
1;
