package WWW::Battie::Modules::ActiveUsers;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module::Model';
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/ message_online /);
use Date::Parse qw(str2time);
use Time::HiRes qw/ gettimeofday /;
use DateTime;

my %functions = (
    functions => {
        activeusers => {
            start => 1,
            popup_list => 1,
            hide => 1,
            show_active => {
                on_run => 1,
            },
            show_chat => {
                on_run => 1,
            },
            chatterbox => 1,
            show_chat_details => 0,
            chat => 1,
            show_active_nicks => 0,
        },
    },
);
my $mysql_ts = '%04d-%02d-%02d %02d:%02d:%02d';
sub functions { %functions }

sub default_actions {
    my ($class, $battie) = @_;
    return {
        guest => [qw/ start popup_list show_active show_chat /],
        user => [qw/ show_active_nicks hide chatterbox show_chat_details chat /],
    };
}


sub model {
    userlist => 'WWW::Battie::Model::DBIC::ActiveUsers',
    user => 'WWW::Battie::Schema::User',
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    my $message_online = $args->{MESSAGE_ONLINE} || 'Others taking refuge in the batcave';
    my $self = $class->new({
            message_online => $message_online,
        });
}

sub activeusers__hide {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $schema = $self->get_schema->{userlist};
    my $session = $battie->get_session;
    my $args = $request->get_args;
    my $submit = $request->get_submit;
    if (($submit->{hide} or $submit->{show}) and not $battie->valid_token) {
        $submit->{delete}
        ? delete $submit->{hide} : delete $submit->{show};
    }
    if ($submit->{hide} or $submit->{show}) {
        if (my $user = $session->get_user) {
            $session->hide_show(schema => $schema, hide => $submit->{hide} ? 1 : 0);
            $self->update_userlist($battie, $user, 'update');
            $battie->set_local_redirect("/activeusers/start");
        }
    }
}

sub update_userlist {
    my ($self, $battie, $user, $what) = @_;
    $battie->module_call(cache => 'delete_cache', '/activeusers/userlist');
    return;
}

sub activeusers__show_active {
    my ($self, $battie) = @_;
	return unless $battie->response->get_needs_navi;
    my $data = $battie->get_data;
    my $session = $battie->get_session;
    my $user_id;
    if (my $user = $session->get_user) {
        $self->init_db($battie);
        $data->{activeusers}->{user_visible} = $session->cgis->hidden ? 0 : 1;
    }
    my $stats = $battie->module_call(cache => 'from_cache', 'activeusers/userlist');
    unless ($stats) {
        $self->init_db($battie);
        my $schema = $self->get_schema->{userlist};
        my $minus10 = time - 60 * 10;
        my $all = $schema->resultset('Session')->search(
                {
                    mtime => { '>=', $minus10 },
                },
                {
                    order_by => 'mtime desc',
                    select => [qw/ user_id data /],
                }
            );
        my @active_users;
        my %seen;
        while (my $item = $all->next) {
            next if $item->user_id && $seen{ $item->user_id }++; # avoid double entries
            push @active_users, $item->readonly;
        }
        my @u;
        my $user_schema = $self->get_schema->{user};
        my @guests;
        my @user_au = grep { $_->user_id } @active_users;
        my @uids = map { $_->user_id } @user_au;
        my @users;
        if (@uids) {
            @users = $user_schema->resultset('User')->search({
                    id => { IN => \@uids },
                },
                {
                    select => [qw/ id nick /],
                })->all;
        }
        my %uids;
        for my $user (@users) {
            $uids{ $user->id } = $user->readonly([qw/ id nick /]);
        }

        for my $au (@active_users) {
            unless ($au->user_id) {
                push @guests, $au;
                next;
            }
            my $user_ro = $uids{ $au->user_id };
            push @u, $user_ro;
            $u[-1]->set_visible(!$au->hidden);
        }
        my @visible = grep { $_->get_visible } @u;
        my $anonymous_count = @u - @visible;
        $stats->{anonymous_count} = $anonymous_count;
        $stats->{guest_count} = @guests;
        $stats->{count} = @visible;
        $stats->{list} = \@visible;
        $battie->module_call(cache => 'cache', 'activeusers/userlist', $stats, 60);
    }
    else { $self->load_db($battie) }
    $data->{activeusers}->{list} = $stats->{list};
    $data->{activeusers}->{count} = $stats->{count};
    $data->{activeusers}->{guest_count} = $stats->{guest_count};
    $data->{activeusers}->{anonymous_count} = $stats->{anonymous_count};
    $data->{activeusers}->{total_count} = $stats->{anonymous_count} + $stats->{count};
    $data->{activeusers}->{message_online} = $self->get_message_online;
}

sub activeusers__show_chat {
    my ($self, $battie) = @_;
	return unless $battie->response->get_needs_navi;
    return if $battie->request->get_page eq 'activeusers'
        && $battie->request->get_action =~ m/^(?:chatterbox|chat)$/;
    $self->init_db($battie);
    my $schema = $self->get_schema->{userlist};
    my ($msgs, $unique) = $self->fetch_chatterbox($battie, 60 * 5, 10);
    my $data = $battie->get_data;
    $data->{chat}->{msgs} = $msgs;
    $data->{chat}->{user_count} = keys %$unique;
}

sub activeusers__chatterbox {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{userlist};
    my ($msgs, $unique) = $self->fetch_chatterbox($battie, 60 * 5, 30);
    my $data = $battie->get_data;
    $data->{chat}->{msgs} = $msgs;
    $data->{chat}->{user_count} = keys %$unique;
    $data->{chat}->{big} = 1;
    $data->{main_template} = "activeusers/chatterbox.html";
}

sub fetch_chatterbox {
    my ($self, $battie, $sec, $max) = @_;
    my $schema = $self->get_schema->{userlist};
    my $session = $battie->get_session;
    my $uid = 0;
    if (my $user = $session->get_user) {
        $uid = $user->id;
    }
    #my $rows = $max;
    my $rows = 30;
    my $delta = 60 * 10;
    my $cached = $battie->from_cache('activeusers/chatterbox');
    my $msgs = [];
    my $unique;
    if ($cached) {
        ($msgs, $unique) = @$cached;
    }
    else {
        my $now = DateTime->now->subtract(minutes => 10);
        my @msgs = $schema->resultset('Chatterbox')->search(
            {
                ctime => { '>=', $now },
            },
            {
                order_by => 'ctime desc, seq desc',
                rows => $rows,
            },
        )->all;
        for my $msg (reverse @msgs) {
            my $ro = $msg->readonly;
            my $text = $ro->msg;
            if ($text =~ s#^/me ##) {
                $ro->set_action(1);
                $text = '[user]' . $ro->user_id . '[/user] ' . $text;
                $ro->set_msg($text);

            }
            my $to;
            if ($msg->rec) {
                $to = $battie->module_call(login => 'get_user_by_id', $msg->rec, [qw/ id nick /]);
                #$ro->set_user($to->readonly);
            }
            my $from = $battie->module_call(login => 'get_user_by_id', $ro->user_id, [qw/ id nick /]);
            $unique->{ $from->id }++;
            $ro->set_user($from ? $from->readonly([qw/ id nick /]) : undef);
            if ($msg->user_id == $uid) {
                $ro->set_self(1);
            }
            my $re = $battie->get_render->render_message_chatterbox($ro->msg);
            $ro->set_rendered($re);
            $ro->set_ctime_epoch($ro->ctime);
            $ro->set_ctime(undef);
            push @$msgs, $ro;
        }
        $battie->to_cache('activeusers/chatterbox', [$msgs, $unique], 2 * 60);
    }
    if (@$msgs > $max) {
        @$msgs = @$msgs[ $#$msgs - $max + 1 .. $#$msgs ];
    }
    return ($msgs, $unique);
}

my %reloads = (
    10000 => 6,
    15000 => 8,
    20000 => 9,
    30000 => 8,
    60000 => 5,
    120000 => 5,
);
my @reloads = sort { $a <=> $b } keys %reloads;

sub activeusers__chat {
    my ($self, $battie) = @_;
    $battie->response->set_needs_navi(0);
    $self->init_db($battie);
    my $schema = $self->get_schema->{userlist};
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    if ($submit->{send} and not $battie->valid_token) {
        $battie->token_exception;
    }
    my $text = $request->param('chat.msg');
    $text = '' unless defined $text;
    #use Devel::Peek;
    #Dump $text;
    #$text = Encode::encode_utf8($text) if $request->param('is_ajax');
    #Dump $text;
    my $data = $battie->get_data;
    if ($submit->{send}) {
        my $session = $battie->get_session;
        my $reload = $request->param('chat.reload') || 0;
        my $reload_count = $request->param('chat.count') || 0;
        #warn __PACKAGE__.':'.__LINE__.": !!! $reload, $reload_count\n";
        for ($reload, $reload_count) {
            tr/0-9//cd;
            $_ ||= 0;
        }
        unless (exists $reloads{$reload}) {
            $reload = 0;
        }
        if (length $text and  my $user = $session->get_user) {
            my $uid = $user->id;
            $reload = 10000;
            $reload_count = 0;
            my $to;
            if ($text =~ s/^\[([\w]+)\]://) {
                my $nick = $1;
                $to = $battie->module_call(login => 'get_user_by_nick', $nick);
                if ($to) {
                    $to = $to->id;
                    $text = '[user]' . $to . '[/user]:' . $text;
                }
                else {
                    $text = "[$nick]:" . $text;
                }
            }
            $schema->txn_begin;
            my $msg;
            my $ts = DateTime->now;
            eval {
                my $exists = $schema->resultset('Chatterbox')->search(
                    {
                        ctime => $ts,
                    },
                    {
                        rows => 1,
                        order_by => 'seq desc' ,
                        for => 'update',
                    },
                )->single;
                my $seq = 1;
                if ($exists) {
                    $seq = $exists->seq + 1;
                }
                $msg = $schema->resultset('Chatterbox')->create({
                    user_id => $uid,
                    rec => $to,
                    msg => $text,
                    seq => $seq,
                });
            };
            if ($@) {
                warn __PACKAGE__.':'.__LINE__.": Error: $@\n";
                $schema->txn_rollback;
                $data->{chat}->{ok} = 0;
            }
            else {
                $schema->txn_commit;
                $battie->module_call(cache => 'delete_cache', '/activeusers/chatterbox');
                $data->{chat}->{ok} = 1;
            }
        }
        else {
            my $limit = $reloads{$reload} || 0;
            #warn __PACKAGE__.':'.__LINE__.": !!!!! $reload, $reload_count (@reloads)\n";
            if ($reload and $reload_count >= $limit) {
                my $pos = $#reloads;
                for my $i (0 .. $#reloads) {
                    $pos = $i, last if $reloads[$i] == $reload;
                }
                if ($pos == $#reloads) {
                    #end, don't reload any more
                    $reload = 0;
                    $reload_count = 0;
                }
                else {
                    $reload = $reloads[$pos + 1];
                    $reload_count = 0;
                }
            }
            #warn __PACKAGE__.':'.__LINE__.": !!!!! $reload, $reload_count\n";
        }
        if ($request->param('is_ajax')) {
            my ($msgs, $unique) = $self->fetch_chatterbox($battie, 60 * 5, $request->param('from_chatterbox') ? 30 : 10);
            $data->{chat}->{msgs} = $msgs;
            $data->{chat}->{user_count} = keys %$unique;
            $data->{main_template} = "activeusers/ajax.html";
            $data->{chat}->{big} = ! ! $request->param('from_chatterbox');
            $data->{chat}->{ok} = 1;
            $data->{chat}->{reload} = $reload;
            $data->{chat}->{reload_count} = $reload_count + 1;
            return;
        }
        $battie->set_local_redirect("/activeusers/chatterbox");
    }

}

sub activeusers__start {
    my ($self, $battie) = @_;
}

sub activeusers__popup_list {
}

1;
