package WWW::Battie::Modules::Member;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use base 'WWW::Battie::Module::Model';
use WWW::Battie::Pager;
use WWW::Battie::Sorter;
use MIME::Lite;
use URI::Escape qw/ uri_escape /;
my %functions = (
    functions => {
        member => {
            start              => 1,
                list           => 1,
                geo            => 1,
                stats          => 1,
                profile        => 1,
                send_pm        => 1,
                view_pm        => 1,
                delete_pm      => 1,
                view_box       => 1,
                box_list       => 1,
                create_box     => 1,
                edit_box       => 1,
                edit_pms       => 1,
                edit_abook     => 1,
                abook          => 1,
                settings       => 1,
                message_status => {
                    on_run => 1,
                },
        }
    }
);
sub functions { %functions }

sub default_actions {
    my ($class, $battie) = @_;
    return {
        guest => [qw/ stats geo /],
        user => [qw/ list profile send_pm view_pm delete_pm view_box create_box edit_box edit_pms edit_abook abook settings message_status box_list /],
    };
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        my @links;

        my $allow = $battie->get_allow;
        if ($allow->can_do(member => 'view_box')) {
            my $image = 'email.png';
            my $alt = "mail";
            my $class = '';
            my $unread_messages = $battie->get_data->{member}->{new_messages};
            my $text = $battie->translate('member_messages');
            if ($unread_messages) {
                $class = 'new_pm';
                $image = 'mail_new.png';
                $alt = "new mail";
                $text .= " ($unread_messages)";
            }
            push @links, {
                link_class => $class,
                link => ['member', 'view_box'],
                image => $image,
                text => $text,
                alt => $alt,
            };
        }
        if ($allow->can_do(member => 'list')) {
            push @links, {
                link => ['member', 'list'],
                image => 'people.png',
                text => $battie->translate('member_members'),
            };
        }
        elsif ($allow->can_do(member => 'stats')) {
            push @links, {
                link => ['member', 'stats'],
                image => 'people.png',
                text => 'Statistics',
            };
        }
        return @links;
    };
}

sub model {
    user => 'WWW::Battie::Schema::User',
}

sub member__start {
}

sub member__settings {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $battie->response->set_no_cache(1);
    my $userid = $battie->session->userid;
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    my $settings = $schema->resultset('Settings')->find({user_id => $userid});
    unless ($settings) {
        $settings = $schema->resultset('Settings')->create({user_id => $userid});
    }
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    if ($submit->{save} and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{save}) {
        my $notify = $request->param('notify') ? 1 : 0;
        if ($notify != $settings->send_notify) {
            $settings->update({ send_notify => $notify });
        }
        $battie->writelog($settings);
        $battie->set_local_redirect("/member/settings");
    }
    else {
        $data->{member}->{settings} = $settings->readonly;
    }
}

sub member__edit_abook {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    $battie->response->set_no_cache(1);
    my @contact_ids = grep { ! tr/0-9//c and length $_ } $request->param('contact.id');
    $self->exception("Argument", "Not enough arguments") unless @contact_ids;
    my $me = $battie->get_session->user;
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    my @users = $schema->resultset('User')->find({ id => { 'IN' => [@contact_ids] }});
    $self->exception("Argument", "Not enough arguments") unless @users;
    my $note = $request->param('contact.note');
    my $data = $battie->get_data;
    my $submit = $request->get_submit;
    if ($submit->{add} and not $battie->valid_token) {
        delete $submit->{add};
        $data->{member}->{error}->{token} = 1;
    }
    if ($submit->{add}) {
        for my $user (@users) {
            my $entry = $schema->resultset('Addressbook')->find_or_create({
                    user_id    => $me->id,
                    contactid => $user->id,
                    blacklist => 0,
                    note      => $note,
                    ctime     => undef,
                });
        }
        if (@contact_ids > 1) {
            # added more than one user
            $battie->set_local_redirect("/member/abook");
        }
        else {
            $battie->set_local_redirect("/member/abook/$contact_ids[0]");
        }
        return;
    }
    $data->{member}->{contacts} = [map { $_->readonly } @users];
}

sub member__abook {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    my $args = $request->get_args;
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    if (my ($id) = @$args) {
        # show one entry
        $self->exception("Argument", "Invalid id '$id'") if $id =~ tr/0-9//c;
        my $entry = $schema->resultset('Addressbook')->find({
                user_id => $battie->get_session->userid,
                contactid => $id,
            });
        $self->exception("Argument", "No addressbook entry for id '$id'") unless $entry;
        if ($submit->{save_note} and not $battie->valid_token) {
            delete $submit->{save_note};
            $data->{member}->{error}->{token} = 1;
        }
        if ($submit->{delete} and not $battie->valid_token) {
            delete $submit->{delete};
            $data->{member}->{error}->{token} = 1;
        }
        if ($submit->{save_note}) {
            my $note = $request->param('note');
            #use Devel::Peek;
            #warn __PACKAGE__.':'.__LINE__.": note=$note\n";
            #Dump $note;
            $entry->note($note);
            $entry->update;
            if ($request->param('is_ajax')) {
                $data->{main_template} = "member/ajax.html";
                return;
            }
            $battie->set_local_redirect("/member/abook/" . $id);
            return;
        }
        elsif ($submit->{delete}) {
            $entry->delete;
            $battie->set_local_redirect("/member/abook");
            return;
        }
        my $ro = $entry->readonly;
        my $me = $entry->user->readonly;
        my $co = $entry->contact->readonly;
        $ro->set_user($me);
        $ro->set_contact($co);
        $data->{member}->{contact} = $ro;

    }
    else {
        my $rows = 20;
        my $page = $request->pagenum(100);
        # show all addressbook entries
        my $sort = $request->param('so');
        my $new_sort = $request->param('sort');
        my $sorter = WWW::Battie::Sorter->from_cgi({
                # users should not be able to sort by several sort-fields
                max_sort => 4,
                cgi => $sort,
                new => $new_sort,
                fields => [qw(nick ctime blacklist)],
                uri => $battie->self_url . '/member/abook?p='.$page.';so=%s',
            });
        $sorter->to_template;
        my $order_by_default = "nick asc";
        my @order_by;
        my %order_map = (
            nick => 'contact.nick',
            ctime => 'me.ctime',
            bl => 'blacklist',
        );
        for my $o (@{ $sorter->sort }) {
            push @order_by, "$order_map{ $o->{field} } " . ($o->{order} eq 'A' ? "ASC" : "DESC");
        }
        if (@order_by) {
            $order_by_default = join ", ", @order_by;
        }
        my $param = $sorter->param;
        my ($search, $count_ref) = $schema->count_search( Addressbook =>
            { user_id => $battie->get_session->userid },
            { rows => $rows, page => $page, join => 'contact', order_by => $order_by_default },
        );
        my @contacts;
        my $count;
        while (my $entry = $search->next) {
            $count = $count_ref->() unless defined $count;
            my $ro = $entry->readonly;
            $ro->set_contact($entry->contact->readonly);
            push @contacts, $ro;
        }
        my $pager = WWW::Battie::Pager->new({
                items_pp => $rows,
                total_count => $count,
                before => 3,
                after => 3,
                current => $page,
                link => $battie->self_url
                    . '/member/abook?p=%p;so=' . $param
                    ,
                title => '%p',
            })->init;
        $data->{member}->{pager} = $pager;
        $data->{member}->{sorter} = $sorter;
        $data->{member}->{contacts} = \@contacts;
    }
}

sub member__delete_pm {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $pm = $schema->resultset('PMessage')->find($id);
    $self->exception("Argument", "Message '$id' does not exist") unless $pm;
    my $box = $pm->box;
    $self->exception("Argument", "Message '$id' is not visible by you") unless $box->user_id == $battie->get_session->userid;
    my $data = $battie->get_data;
    my $submit = $request->get_submit;
    if ($submit->{delete} and not $battie->valid_token) {
        $submit->{preview} = delete $submit->{delete};
        $data->{member}->{error}->{token} = 1;
    }
    if ($submit->{preview}) {
        $data->{member}->{box} = $box->readonly;
        $data->{member}->{pm} = ($self->render_pm($battie, $pm))[0];
    }
    elsif ($submit->{delete}) {
        my $id = $pm->id;
        $schema->resultset('MessageRecipient')->search({
            message_id => $pm->id,
        })->delete;
        $pm->delete;
        my $response = $battie->get_response;
        my $url = $battie->self_url;
        $response->set_redirect("$url/member/view_box/" . $box->id);
        $battie->writelog($pm);
        return;
    }
}

sub member__box_list {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $response = $battie->response;
    $response->set_no_cache(1);
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $boxes = $self->fetch_box_list($battie);
    my @box_ids = map { $_->id } @$boxes;
    my $counts = $schema->resultset('PMessage')->search({
            box_id => { IN => [@box_ids] },
        },
        {
            group_by => 'box_id',
            select => [
                qw/ box_id /,
                { count => 'id' },
            ],
            as => [qw/ box_id messagecount /],
        });
    my %counts;
    while (my $item = $counts->next) {
        my $box_id = $item->box_id;
        my $count = $item->get_column('messagecount');
        $counts{ $box_id } = $count;
    }
    for my $box (@$boxes) {
        $box->set_message_count($counts{ $box->id } || 0);
    }
    my $data = $battie->get_data;
    $data->{member}->{boxes} = $boxes;
}

sub member__view_box {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $args = $request->get_args;
    my $box;
    my $id;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    unless (@$args) {
        $box = $self->find_box('in', $battie->get_session->userid);
        $id = $box->id;
    }
    else {
        ($id) = @$args;
        $box = $schema->resultset('Postbox')->find($id);
    }
    $self->exception("Argument", "Box '$id' is not visible by you") unless $self->check_box($battie, $box);
    my $count = $box->count_related('messages');
    my $rows = 20;
    my $page = $request->pagenum(100);
    my $pager = WWW::Battie::Pager->new({
            items_pp => $rows,
            total_count => $count,
            before => 3,
            after => 3,
            current => $page,
            link => $battie->self_url
                . "/member/view_box/$id?p=%p"
                ,
            title => '%p',
        })->init;
    my $boxes = $self->fetch_box_list($battie);
    my @messages = $box->search_related(messages => undef,
        {
            order_by => 'mtime desc',
            page => $page,
            rows => $rows,
        });
    my $data = $battie->get_data;
    $data->{member}->{pager} = $pager;
    my $box_ro = $box->readonly;
    my @pms;
    my %uids;
    for my $msg (@messages) {
        my $sender = $msg->sender;
        $uids{ $sender } = undef;
    }
    if (keys %uids) {
        my $usearch = $schema->resultset('User')->search({
                id  => { -in => [sort keys %uids] },
            });
        while (my $user = $usearch->next) {
            $uids{ $user->id } = $user->readonly([qw/ nick id /]);
        }
    }
    for my $msg (@messages) {
        my @acc = qw/ id sender subject has_read ctime /;
        my $ro = $msg->readonly(\@acc);;
        $ro->set_sender($uids{ $msg->sender });
        push @pms, $ro;
    }
#    my @pms = map { $self->render_pm($battie, $_) } @messages;
    $box_ro->set_messages(\@pms);
    $data->{member}->{box} = $box_ro;
    $data->{member}->{boxes} = [$box->id, map {[$_->id, $_->name]} @$boxes];
}

sub fetch_box_list {
    my ($self, $battie) = @_;
    my $schema = $self->get_schema->{user};
    my $fields = [qw/ id name type is_default /];
    my $search = $schema->resultset('Postbox')->search(
        { user_id => $battie->get_session->userid },
        {
            order_by => 'name asc',
            select => $fields,
        },
    );
    my @boxes;
    while (my $box = $search->next) {
        push @boxes, $box->readonly($fields);
    }
    return \@boxes;
}


sub member__edit_pms {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $box = $schema->resultset('Postbox')->find($id);
    $self->exception("Argument", "Box '$id' is not visible by you") unless $self->check_box($battie, $box);
    my $data = $battie->get_data;
    my @pm_ids = grep { !tr/0-9//c and length $_ } $request->param('pm.id');
    unless (@pm_ids) {
        $battie->set_local_redirect("/member/view_box/" . $id);
        return;
    }
    if ($submit->{delete} and not $battie->valid_token) {
        delete $submit->{delete};
        $data->{member}->{error}->{token} = 1;
    }
    if ($submit->{move} and not $battie->valid_token) {
        delete $submit->{move};
        $data->{member}->{error}->{token} = 1;
    }
    if ($submit->{delete}) {
        my $search = $schema->resultset('PMessage')->search(
            {
                box_id => $id,
                id => { 'IN' => [@pm_ids] },
            },
        );
        my $deleted = $search->delete;
        $battie->writelog($box, "deleted $deleted messages");
        $battie->set_local_redirect("/member/view_box/" . $id);
        return;
    }
    elsif ($submit->{move}) {
        my $move_id = $request->param('box.id') || 0;
        $self->exception("Argument", "Not enough arguments") unless $move_id;
        my $move_box = $schema->resultset('Postbox')->find($move_id);
        $self->exception("Argument", "Box '$move_id' does not exist") unless $move_box;
        $self->exception("Argument", "Box '$move_id' is not visible by you") unless $self->check_box($battie, $move_box);
        my $search = $schema->resultset('PMessage')->search(
            {
                box_id => $id,
                id => { 'IN' => [@pm_ids] },
            },
        );
        my $updated = $search->update({
                box_id => $move_id,
            });
        $battie->writelog($box, "moved $updated messages to box $move_id");
        $battie->set_local_redirect("/member/view_box/" . $id);
        return;
    }
}

sub render_pm {
    my ($self, $battie, @msgs) = @_;
    my @rendered;
    for my $msg (@msgs) {
        my $ro = $msg->readonly;
        my $sender = $msg->sender;
        my $user = $battie->module_call(login => 'get_user_by_id', $sender);
        $ro->set_sender($user?$user->readonly:undef);
        unless ($user) {
            warn __PACKAGE__.':'.__LINE__.": unknown sender with id $sender\n";
        }
        my @rec = $msg->recipients;
        $ro->set_recipients([map $_->readonly, @rec]);
        my $text = $msg->message;
        my $re = $battie->get_render->render_message_html($text);
        $ro->set_rendered_message($re);
        my $re_sub = $battie->get_render->render_message_html($msg->subject);
        $ro->set_rendered_subject($re_sub);
        push @rendered, $ro;
    }
    return @rendered;
}

sub delete_message_status_cache {
    my ($self, $battie, $uid) = @_;
    my $ck = "member/unread_messages/$uid";
    $battie->delete_cache($ck);
}

sub member__message_status {
    my ($self, $battie) = @_;
    return unless $battie->get_session->userid;
    return unless $battie->response->get_needs_navi;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $uid = $battie->get_session->userid;
    my $ck = "member/unread_messages/$uid";
    my $unread_messages = $battie->from_cache($ck);
    unless ($unread_messages) {
        my $search = $schema->resultset('Postbox')->search({ user_id => $battie->get_session->userid });
        my @boxes;
        while (my $box = $search->next) {
            push @boxes, $box->readonly;
        }
        my $count = @boxes ? $schema->resultset('PMessage')->count({
                has_read => 0,
                box_id => { IN => [map { $_->id } @boxes] },
            }) : 0;
        $unread_messages->{count} = $count;
        $battie->to_cache($ck, $unread_messages, 60 * 60 * 6);
    }
    $battie->get_data->{member}->{new_messages} = $unread_messages->{count} || 0;
}

sub member__stats {
    my ($self, $battie) = @_;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $stats = $battie->module_call(cache => 'from_cache', 'member/stats');
    unless ($stats) {
        $self->init_db($battie);
        my $schema = $self->get_schema->{user};
        my $count = $schema->resultset('User')->count({
            active => 1,
        });
        my $search = $schema->resultset('User')->search({
            active => 1,
        }, {
            group_by => \'SUBSTR(ctime, 1, 7)',
            select => [
                'ctime',
                { count => 'id' },
            ],
            as => [qw/ ctime id /],
        });
        my %months;
        my %years;
        while (my $user = $search->next) {
            my $ctime = $user->ctime;
            my $count = $user->id;
            my ($year, $month) = $ctime =~ m/^(\d{4})-(\d{2})/;
            $months{"$year-$month"} += $count;
            $years{$year} += $count;
        }
        my @months = reverse sort keys %months;
        @months = @months[0 .. 5] if @months > 6;
        my %last_months;
        @last_months{ @months } = @months{ @months };

        my $lastlogins = $schema->resultset('User')->count({
            active => 1,
            lastlogin => { '>=', DateTime->now->subtract( months => 1 ) },
        });
        $stats->{logged_in_last_month} = $lastlogins;
        $stats->{member_by_year} = \%years;
        $stats->{member_by_last_months} = \%last_months;
        $stats->{membercount} = $count;
        $battie->module_call(cache => 'cache', 'member/stats', $stats, 60 * 60);
    }
    my $data = $battie->get_data;
    $data->{member}->{stats} = $stats;
}

sub update_worldmap {
    my ($self, $battie) = @_;
    $battie->delete_cache('member/worldmap');
}

sub member__geo {
    my ($self, $battie) = @_;
    my $response = $battie->response;
    $response->set_no_cache(1);
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $points = $battie->from_cache('member/worldmap');
    unless ($points) {
        my $search = $schema->resultset('User')->search({
            lastlogin => { '>=' => DateTime->now->subtract(months => 6) },
            active => 1,
            'profile.geo' => { '!=', undef },
        }, {
            prefetch => 'profile',
        });
        my %geo;
        while (my $user = $search->next) {
            my $profile = $user->profile or next;
            my $geo = $profile->geo or next;
            $geo{$geo}++;
        }
        $points = \%geo;
        $battie->to_cache('member/worldmap', $points, 60 * 60 * 3);
    }
    my $data = $battie->get_data;
    $data->{member}->{geo} = $points;
    $data->{member}->{geo_count} = keys %$points;
}

sub member__list {
    my ($self, $battie) = @_;
    my $response = $battie->response;
    $response->set_no_cache(1);
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $rows = 20;
    my $request = $battie->get_request;
    my $page = $request->pagenum(1000);
    my $sort = $request->param('so');
    my $new_sort = $request->param('sort');
	my $start = $request->param('start');
    my $group_id = $request->param('group_id');
	my %start_search;
    my $data = $battie->get_data;
    my $groups = $battie->allow->get_groups;
    if (defined $group_id and not $groups->{ $group_id }) {
        undef $group_id;
    }
    if (not defined $group_id or not exists $groups->{ $group_id }) {
        my @users_by_group;
        my $search = $schema->resultset('User')->search({
                active => 1,
            },
            {
                group_by => 'group_id',
                select => [
                    'group_id',
                    { count => 'id' },
                ],
                as => [qw/ group_id usercount /],
            });
        while (my $item = $search->next) {
            my $group_id = $item->group_id;
            my $usercount = $item->get_column('usercount');
            push @users_by_group, {
                group_name  => $groups->{ $group_id }->[0],
                group_id    => $group_id,
                count       => $usercount,
            };
        }
        @users_by_group = sort { $b->{count} <=> $a->{count} } @users_by_group;
        $data->{member}->{users_by_group} = \@users_by_group;
        return;
    }
	if ($start) {
		if ($start =~ m/^([A-Z])/) {
			$start_search{nick} = { 'LIKE' => "$1%" };
		}
		else {
			$start_search{nick} = {
				'REGEXP' => "^[^a-zA-Z]"
			};
		}
	}
	my $start_enc = defined $start ? uri_escape($start) : '';
    my $sorter = WWW::Battie::Sorter->from_cgi({
            # users should not be able to sort by several sort-fields
            max_sort => 4,
            cgi => $sort,
            new => $new_sort,
            fields => [qw(nick ctime lastlogin location msgs)],
            uri => $battie->self_url . '/member/list?p='.$page.';so=%s;start=' . $start_enc . ";group_id=" . $group_id,
        });
    $sorter->to_template;
    my $order_by_default = "nick asc";
    my @order_by;
    my %order_map = (
        nick => 'me.nick',
        ctime => 'me.ctime',
        lastlogin => 'me.lastlogin',
        msgs => 'settings.messagecount',
        location => 'profile.location',
    );
    for my $o (@{ $sorter->sort }) {
        push @order_by, "$order_map{ $o->{field} } " . ($o->{order} eq 'A' ? "ASC" : "DESC");
    }
    if (@order_by) {
        $order_by_default = join ", ", @order_by;
    }
    my $param = $sorter->param;
    my ($search, $count_ref) = $schema->count_search(User =>
        {
            active => 1,
            group_id => $group_id,
			%start_search,
        },
        {
            join => [qw(settings profile)],
            prefetch => [qw/ settings profile /],
            order_by => $order_by_default,
            rows => $rows,
            page => $page,
        }
    );
    my @members;
    my $count = 0;
    while (my $member = $search->next) {
        $count ||= $count_ref->();
        my $ro = $member->readonly;
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$ro], ['ro']);
        my $settings = $member->settings;
        my $profile = $member->profile;
        if ($profile) {
            $ro->set_profile($profile->readonly);
        }
        if ($settings) {
            $ro->set_settings($settings->readonly);
        }
        push @members, $ro;
    }
    my $pager = WWW::Battie::Pager->new({
            items_pp => $rows,
            total_count => $count,
            before => 3,
            after => 3,
            current => $page,
            link => $battie->self_url
                . '/member/list?p=%p;so=' . $param . ";start=$start_enc" . ";group_id=" . $group_id
                ,
            title => '%p',
        })->init;
	$data->{member}->{starters} = ['A' .. 'Z', '#'];
    $data->{member}->{list} = \@members;
    $data->{member}->{pager} = $pager;
    $data->{member}->{sorter} = $sorter;
    $data->{member}->{group_id} = $group_id;
}

sub member__profile {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $useradmin = $battie->get_allow->can_do('useradmin' => 'edit');
    my $user = $schema->resultset('User')->search(
        # only useradmins should see inactive users
        $useradmin
        ? {id => $id}
        : {id => $id, active => 1}
    )->single;
    $self->exception("Argument", "User '$id' does not exist") unless $user;
    my $data = $battie->get_data;
    my $profile = $schema->resultset('Profile')->find({user_id => $user->id});
    my $user_ro = $user->readonly;
    my $groups = $battie->allow->get_groups;
    $user_ro->set_groupname($groups->{ $user_ro->group_id }->[0]) if $user_ro->group_id;
    if ($profile) {
        my $ro = $profile->readonly;
        if ($ro->sex) {
            $ro->set_sex_label({ f => 'female', m => 'male', t => 'transgender' }->{ $ro->sex });
        }
        $user_ro->set_profile($ro);
    }
    my @roles = sort { $a->name cmp $b->name } map {$_->readonly } $user->roles;
    $data->{member}->{user} = $user_ro;
    $data->{member}->{roles} = [@roles];
}

sub member__view_pm {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $msg = $schema->resultset('PMessage')->find($id);
    $self->exception("Argument", "Message '$id' does not exist") unless $msg;
    my $box = $msg->box;
    $self->exception("Argument", "Message '$id' is not visible by you") unless $self->check_box($battie, $box);
    if (!$msg->has_read) {
        $msg->has_read(1);
        $msg->update;
        my $uid = $battie->get_session->userid;
        $self->delete_message_status_cache($battie, $uid);
    }
    if (my $orig_id = $msg->copy_of) {
        $self->update_read_status($battie, $orig_id);
    }
    my $data = $battie->get_data;
    my ($msg_ro) = $self->render_pm($battie, $msg);
    $data->{member}->{pm} = $msg_ro;
    $data->{member}->{box} = $box->readonly;
}

sub check_box {
    my ($self, $battie, $box) = @_;
    return $box->user_id == $battie->get_session->userid;
}

sub update_read_status {
    my ($self, $battie, $id) = @_;
    my $schema = $self->get_schema->{user};
    my $msg = $schema->resultset('PMessage')->find($id);
    return unless $msg;
    $schema->resultset('MessageRecipient')->search({
        message_id => $id,
        recipient_id => $battie->get_session->userid,
    })->update({
        has_read => 1,
    });
    return;
}

sub member__send_pm {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $response = $battie->response;
    $response->set_no_cache(1);
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my @to = grep { not tr/0-9//c } $request->param('pm.to');
    my @rec;
    my @add = $request->param('pm.add_recip');
    push @to, grep { length $_ and not tr/0-9//c } @add;
    if (@to) {
        my $search = $schema->resultset('User')->search({
                id => { 'IN' => [@to] },
            });
        while (my $to = $search->next) {
            push @rec, $to->readonly;
        }
    }
    my $data = $battie->get_data;
    my $submit = $request->get_submit;
    my $message = $request->param('pm.message');
    my $subject = $request->param('pm.subject');
    my $ro = WWW::Battie::Schema::User::PMessage::Readonly->new({
            message => $message,
            subject => $subject,
        });
    if ($submit->{send} and not $battie->valid_token()) {
        delete $submit->{send};
        $submit->{preview} = 1;
    }
    if ($submit->{send} and not @to) {
        delete $submit->{send};
        $submit->{preview} = 1;
    }
    if ($submit->{preview}) {
    }
    elsif ($submit->{send}) {
        my $outbox = $self->find_box('out', $battie->get_session->userid);
        my $pm_sent = $schema->resultset('PMessage')->create({
                sender => $battie->get_session->userid,
                # yeah this is not normalized but do we care?
                #recipients => join( ',', map { $_->id } @rec ),
                recipients => '',
                message    => $message,
                subject    => $subject,
                has_read   => 1,
                box_id     => $outbox->id,
                ctime      => undef,
                copy_of    => 0,
                has_read   => 0,
            });
        for my $rec (@rec) {
            my $rec_id = $rec->id;
            my $inbox = $self->find_box('in', $rec_id);
            my $settings = $schema->resultset('Settings')->find({user_id => $rec_id});
            my $notify = $settings ? $settings->send_notify : 0;
            my $pm = $schema->resultset('PMessage')->create({
                    sender => $battie->get_session->userid,
                    # yeah this is not normalized but do we care?
                    #recipients => join( ',', map { $_->id } @rec ),
                    recipients => '',
                    message    => $message,
                    subject    => $subject,
                    has_read   => 0,
                    box_id     => $inbox->id,
                    copy_of    => $pm_sent->id,
                    sent_notify => ($notify ? 0 : 1),
                    ctime      => undef,
                });
            my $msg_rec = $schema->resultset('MessageRecipient')->create({
                message_id => $pm->id,
                recipient_id => $rec_id,
                has_read   => 0,
            });
            my $msg_rec2 = $schema->resultset('MessageRecipient')->create({
                message_id => $pm_sent->id,
                recipient_id => $rec_id,
                has_read   => 0,
            });
            $self->delete_message_status_cache($battie, $rec_id);
        }
        my $msg_id = $pm_sent->id;
        $battie->set_local_redirect("/member/view_pm/$msg_id");
        $battie->writelog($pm_sent);
        return;
    }
    my $quote = $request->param('pm.quote');
    if (defined $quote) {
        my $q = $schema->resultset('PMessage')->find($quote);
        my $quote_box = $q->box;
        $self->exception("Argument", "Message '$quote' is not visible by you") unless $quote_box->user_id == $battie->get_session->userid;
        my $subj = $q->subject;
        if ($subj =~ s/^Re: /Re^2: /) {
        }
        elsif ($subj =~ s{^Re\^(\d+): }{'Re^'.($1+1).': '}e) {
        }
        else {
            $subj = "Re: $subj";
        }
        $ro->set_subject($subj);
        $ro->set_message('[quote]' . $q->message . '[/quote]');
    }
    my $search = $schema->resultset('Addressbook')->search({
            user_id => $battie->get_session->userid,
        });
    my %contacts;
    while (my $contact = $search->next) {
        my $user = $contact->contact;
        my $ro = $contact->readonly;
        $ro->set_contact($user->readonly);
        $contacts{ $contact->contactid } = $ro;
    }
    for my $rec (@rec) {
        delete $contacts{ $rec->id };
    }
    my $re = $battie->get_render->render_message_html($ro->message);
    $ro->set_rendered_message($re);
    $data->{member}->{pm} = $ro;
    $data->{member}->{recipients} = \@rec;
    $data->{member}->{abook} = [undef,
        map { [$_->contactid, $_->contact->nick] } sort { $a->contact->nick cmp $b->contact->nick } values %contacts
    ];
}

sub find_box {
    my ($self, $type, $userid) = @_;
    my $schema = $self->get_schema->{user};
    my $box = $schema->resultset('Postbox')->search({
            type => $type,
            is_default => 1,
            user_id => $userid,
        })->single;
    unless ($box) {
        $box = $schema->resultset('Postbox')->create({
                type => $type,
                is_default => 1,
                user_id => $userid,
                name => $type eq 'out' ? 'OUTBOX' : 'INBOX',
            });
    }
    return $box;
}

sub member__edit_box {
    my ($self, $battie) = @_;
    #my $battie = $self->battie;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $request = $battie->request;
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    my $box = $schema->resultset('Postbox')->find($id);
    my $box_ro = $box->readonly;
    my $data = $battie->get_data;
    if (($submit->{delete} or $submit->{save})
            and not $battie->valid_token) {
        if ($submit->{delete}) {
            delete $submit->{delete};
        }
        if ($submit->{save}) {
            delete $submit->{save};
        }
        $data->{member}->{error}->{token} = 1;
    }
    if ($submit->{save}) {
        my $name = $request->param('box.name');
        $box->name($name);
        $box->update;
        $battie->set_local_redirect("/member/box_list");
    }
    elsif ($submit->{delete}) {
        my $search = $box->search_related('messages');
        my $deleted = $search->delete;
        $box->delete;
        $battie->writelog($box, "deleted box and $deleted messages");
        $battie->set_local_redirect("/member/box_list");
        return;
    }
    $data->{member}->{box} = $box_ro;
}

sub member__create_box {
    my ($self, $battie) = @_;
    #my $battie = $self->battie;
    my $request = $battie->request;
    my $response = $battie->response;
    $response->set_no_cache(1);
    my $submit = $request->get_submit;
    my $box_name = $request->param('box.name');
    my $data = $battie->get_data;
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    if ($submit->{create} and not $battie->valid_token) {
        delete $submit->{create};
        $data->{member}->{error}->{token} = 1;
    }
    if ($submit->{create}) {
        my $exists = $schema->resultset('Postbox')->find({
                type       => 'in',
                user_id    => $battie->session->userid,
                name       => $box_name,
            });
        if ($exists) {
            $data->{member}->{error}->{exists} = 1;
            delete $submit->{create};
        }
    }
    if ($submit->{create}) {
        my $box = $schema->resultset('Postbox')->create({
                type       => 'in',
                is_default => 0,
                user_id    => $battie->session->userid,
                name       => $box_name,
            });
        $battie->set_local_redirect("/member/view_box/" . $box->id);
    }
    else {
        $data->{member}->{box}->{name} = $box_name;
    }
}

sub fetch_settings {
    my ($self, $battie, $rw, $uid) = @_;
    $uid ||= 0;
    if ($rw eq 'cache') {
        $self->load_db($battie);
        my $settings = $battie->from_cache('member/settings/' . $uid);
        unless ($settings) {
            $self->init_db($battie);
            my $schema = $self->schema->{user};
            my $profile = $schema->resultset('Profile')->find($uid, {
                    select => [
                        qw/ user_id meta /
                    ],
                });
            $settings = $profile ? ($profile->meta || {}) : {};
            $battie->to_cache("member/settings/$uid", $settings, 60 * 60 * 24 * 5);
        }
        return $settings;
    }
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    my $profile = $schema->resultset('Profile')->find($uid, {
            select => [
                qw/ user_id meta /
            ],
        });
    return $profile;
}

sub cron_notify {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{user};
    my $search = $schema->resultset('Postbox')->search({
            type => 'in',
            is_default => 1,
        });
    my $sent = 0;
    while (my $box = $search->next) {
        my $user = $box->user;
        my $profile = $schema->resultset('Profile')->find({user_id => $user->id});
        my $email = $profile ? $profile->email : undef;
        my $box_ro = $box->readonly;
        $box_ro->set_user($user->readonly);
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$box_ro], ['box_ro']);
        my $msearch = $schema->resultset('PMessage')->search(
            {
                box_id => $box->id,
                sent_notify => 0,
            },
        );
        unless ($email) {
            $msearch->update({ sent_notify => 1 });
            next;
        }
        my @msgs;
        while (my $msg = $msearch->next) {
            my $ro = $msg->readonly;
            $ro->set_box($box_ro);
            my $sender = $msg->sender_user;
            $ro->set_sender_user($sender->readonly);
            push @msgs, $ro;
        }
        next unless @msgs;
        $battie->init_timezone_translation('default', 'de_DE');
        my $htc = $battie->create_htc(
            filename => 'member/notify.txt',
            path => $battie->template_path,
            default_escape => 0,
        );
        my $data = $battie->get_data;
        $data->{member}->{msgs} = \@msgs;
        my $param = $battie->get_template_param;
        $battie->fill_global_template_params($param);
        $htc->param( %$param );
        my $body = $htc->output;
        $battie->send_mail({
            to => $email,
            subject => "Battie - Notification",
            body => $body,
        });

        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$body], ['out']);
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@msgs], ['msgs']);
        $msearch->update({ sent_notify => 1 });
        $sent++;
    }
    return $sent;


}

1;
