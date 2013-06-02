package WWW::Battie::Modules::Useradmin;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module::Model';
use base 'WWW::Battie::Accessor';
__PACKAGE__->follow_good_practice;
__PACKAGE__->mk_accessors(qw(paging));
my %functions = (
    functions => {
        useradmin => {
            start => 1,
            list => 1,
            edit => 1,
            create => 1,
            delete => 1,
            edit_user_roles => 1,
            edit_role  => 1,
            list_roles => 1,
            create_role => 1,
            clear_cache => 1,
        },
    },
);
sub functions { %functions }

sub default_actions {
    my ($class, $battie) = @_;
    return {
        useradmin => [qw/ start list edit create delete edit_user_roles edit_role list_roles create_role clear_cache /],
    };
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        return {
            link => ['useradmin', 'start'],
            text => 'Useradmin',
        };
    };
}

sub model {
    user => 'WWW::Battie::Schema::User',
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    my $users = $args->{ROWS_USER_LIST} || 10;
    my $self = $class->new({
            paging => {
                users => $users,
            },
        });
}



sub useradmin__list {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    $battie->response->set_no_cache(1);
    my $rows = $self->paging->{users};
    my $page = $battie->request->param('p') || 1;
    my $schema = $self->get_schema->{user};
    my $args = $battie->request->get_args;
    my $type = "active";
    if (@$args) {
        ($type) = @$args;
    }
    my ($search, $count_ref) = $schema->count_search(User =>
        {
            active => ($type eq 'inactive') ? 0 : 1,
        },
        {
                order_by => 'ctime desc',
                page => $page,
                rows => $rows,
        }
    );
    my @users;
    while (my $user = $search->next) {
        push @users, $user;
    }
    my $count = $count_ref->();
    my $groups = $battie->allow->get_groups;
    for my $user (@users) {
        my $ro = $user->readonly;
        $ro->set_groupname($groups->{ $ro->group_id }->[0]) if $ro->group_id;
        my @roles = $user->roles;
        #my @roles = $user->userroles->search_related('role');
        my @roles_ro = map { $_->readonly } @roles;
        $user = $ro;
        $ro->set_roles(\@roles_ro);
    }
    my $pager = WWW::Battie::Pager->new({
            items_pp => $rows,
            before => 3,
            after => 3,
            total_count => $count,
            current => $page,
            link => $battie->self_url
                . "/useradmin/list/$type?p=%p"
                ,
            title => '%p',
        })->init;
    $battie->get_data->{useradmin}->{pager} = $pager;
    $battie->get_data->{users} = \@users;
}

sub get_users {
    my ($self, $battie) = @_;
    my $schema = $self->get_schema->{user};
    my $user_rs = $schema->resultset('User');
    my $iter = $user_rs->search;
    my @users;
    while (my $user = $iter->next) {
        push @users, $user->readonly;
    }
    return \@users;
}

sub useradmin__delete {
    my ($self, $battie) = @_;
    $self->exception("Argument", "Not implemented yet");
	# TODO delete also forum messages etc.
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($userid) = @$args;
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    if (($submit->{delete} || $submit->{__default}) and not $battie->valid_token) {
        delete $submit->{delete};
        delete $submit->{__default};
        $data->{useradmin}->{error}->{token} = 1;
    }
    if ($submit->{delete} || $submit->{__default}) {
        $self->exception("Argument", "'$userid' is not a valid userid")
            unless $schema->valid_userid($userid);
        my $user = $schema->resultset('User')->find($userid);
        $self->exception("Argument", "'$userid' does not exist") unless $user;
        $battie->writelog($user);
        $user->delete;
        $battie->set_local_redirect('/useradmin/list');
    }
}

sub useradmin__edit {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $battie->response->set_no_cache(1);
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($userid) = @$args;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    $self->exception("Argument", "'$userid' is not a valid userid")
        unless $schema->valid_userid($userid);
    my $user = $schema->resultset('User')->find($userid);
    $self->exception("Argument", "User '$userid' does not exist") unless $user;
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    if ($submit->{change_pass}) {
        $battie->require_token;
    }
    if ($submit->{save}) {
        $battie->require_token;
    }
    if ($submit->{change_pass}) {
        $user->password($schema->encrypt(scalar $request->param('user.pass')));
        $user->update;
        $battie->writelog($user, "change_pass");
        $battie->set_local_redirect('/useradmin/edit/' . $userid);
    }
    elsif ($submit->{save}) {
        my $active = $request->param('active') || 'no';
        my $bool = $active eq 'yes' ? 1 : 0;
        $user->active($bool);
        $user->update;
        $battie->writelog($user, "$active: $bool");
        $battie->delete_cache("login/user_token/$userid");
        $battie->set_local_redirect('/useradmin/edit/' . $userid);
    }
    $data->{useradmin}->{user} = $user;
    my $profile = $schema->resultset('Profile')->find({ user_id => $user->id});
    $data->{useradmin}->{profile} = $profile ? $profile->readonly : undef;
}

sub useradmin__create {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $schema = $self->get_schema->{user};
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    if (($submit->{create} || $submit->{__default}) and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{create} || $submit->{__default}) {
        my $username = $request->param('user.name');
        $self->exception("Argument", "Not enough arguments") unless length $username;
        $self->exception("Argument", "'$username' is not a valid username")
            unless $schema->valid_username($username);
        my $exists = $schema->resultset('User')->find({
            nick => $username,
        });
        if ($exists) {
            $battie->get_data->{useradmin}->{error}->{user_exists} = 1;
        }
        else {
            my $user = $schema->resultset('User')->create({
                nick => $username,
                password => '',
                ctime => undef,
            });
            $battie->writelog($user);
            $battie->set_local_redirect('/useradmin/edit/' . $user->get_id);
        }
    }
}

sub useradmin__start {
}

sub useradmin__edit_user_roles {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $request = $battie->get_request;
    my $response = $battie->get_response;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my $data = $battie->get_data;
    my ($user_id) = @$args;
    $self->exception("Argument", "'$user_id' is not a valid userid")
        unless $schema->valid_userid($user_id);
    my $user = $schema->resultset('User')->find($user_id);
    $self->exception("Argument", "User '$user_id' does not exist") unless $user;
    $data->{useradmin}->{user} = $user;
    #warn Data::Dumper->Dump([\$args], ['args']);
    my $user_roles2 = $battie->module_call(login => 'get_roles_by_user', $user_id);
    my $submit = $request->get_submit;
    my $roles = $battie->module_call(login => 'get_roles_by_ids',
        map { $_->role_id } @$user_roles2
    );
    my @all_roles = $battie->module_call(login => 'get_all_roles');
    my %valid_roles = map {$_->id => 1 } @all_roles;
    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%valid_roles], ['valid_roles']);
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$roles], ['roles']);
    if ($submit->{add_roles} and not $battie->valid_token) {
        delete $submit->{add_roles};
        $data->{useradmin}->{error}->{token} = 1;
    }
    if ($submit->{remove_roles} and not $battie->valid_token) {
        delete $submit->{remove_roles};
        $data->{useradmin}->{error}->{token} = 1;
    }
    if ($submit->{add_roles}) {
        my @roles_to_add = grep length, $request->param('system.roles');
        my $roles = $battie->module_call(login => 'get_roles_by_ids', @roles_to_add);
        my $ur_rs = $schema->resultset('UserRole');
        for my $role (@$roles) {
            $ur_rs->find_or_create({
                    role_id => $role->id,
                    user_id => $user_id,
                });
        }
        $battie->delete_cache('login/user_roles/' . $user_id);
        $battie->writelog($user, "add_roles");
        $battie->set_local_redirect('/useradmin/edit_user_roles/' . $user_id);
    }
    elsif ($submit->{remove_roles}) {
        my @roles_to_remove = grep length, $request->param('useradmin.roles');
        my $roles = $battie->module_call(login => 'get_roles_by_ids', @roles_to_remove);
        my $ur_rs = $schema->resultset('UserRole');
        for my $role (@$roles) {
            my $ur = $ur_rs->find({
                    role_id => $role->id,
                    user_id => $user_id,
                });
                $ur->delete if $ur;
        }
        $battie->writelog($user, "remove_roles");
        $battie->delete_cache('login/user_roles/' . $user_id);
        $battie->set_local_redirect('/useradmin/edit_user_roles/' . $user_id);
    }
    else {
        # options
        my %selected = map { $_->name => 1 } @$roles;
        #warn __PACKAGE__.$".Data::Dumper->Dump([\%selected], ['selected']);
        $data->{useradmin}->{user_roles} = [undef, map {
            [$_->id, $_->name . ' (' . $_->rtype . ')']
        } @$roles];
        $data->{useradmin}->{available_roles} = [undef, map {
            [$_->id, $_->name . ' (' . $_->rtype . ')']
        } grep { not $selected{$_->name} } @all_roles];
    }
}

sub useradmin__edit_role {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $role_rs = $schema->resultset('Role');
    my $role_action_rs = $schema->resultset('RoleAction');
    my $request = $battie->get_request;
    my $response = $battie->get_response;
    my ($args) = $request->get_args;
    my $data = $battie->get_data;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->exception("Argument", "'$id' is not a valid role id")
        unless $schema->valid_roleid($id);
    my $role = $role_rs->find($id);
    $data->{useradmin}->{role_id} = $id;
    $data->{useradmin}->{role} = $role->readonly;
    my $modules = $battie->get_module_list;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$modules], ['modules']);
    $self->exception("Argument", "Role '$id' does not exist") unless $role;
    my @actions = $role->actions;
    my %selected = map { $_->action => 1 } @actions;
    my $submit = $request->get_submit;
    my %system_actions;
    for my $module (keys %$modules) {
        my $actions = $modules->{$module};
        $system_actions{"$module/$_"} = 1 for ("*", keys %$actions);
    }
    #warn __PACKAGE__.$".Data::Dumper->Dump([\%system_actions], ['system_actions']);
    my @submits = grep { $submit->{$_} } qw(
        add_modules show_actions add_actions remove_actions set_name
    );
    if (@submits and not $battie->valid_token) {
        delete $submit->{$_} for @submits;
        $data->{useradmin}->{error}->{token} = 1;
    }
    if ($submit->{set_name}) {
        my $name = $request->param('role.name');
        $self->exception("Argument", "'$name' is not a valid role name")
            unless $schema->valid_rolename($name);
        $role->update({ name => $name });
        $battie->writelog($role, "set_name");
        $battie->set_local_redirect('/useradmin/edit_role/' . $id);
        return;
    }
    elsif ($submit->{add_modules}) {
        my @modules_to_add = grep length, $request->param('system.modules');
        for my $m (@modules_to_add) {
            next if $m eq '*';
            $self->exception("Argument", "Module '$m' does not exist")
                unless $modules->{$m};
        }
        my @new_modules = grep {
            not $selected{$_}
        } map {
            "$_/*"
        } @modules_to_add;
        for my $new_module (@new_modules) {
            $role_action_rs->create({
                role_id => $id,
                action => $new_module,
            });
        }
        $battie->writelog($role, "add_modules");
        $battie->set_local_redirect('/useradmin/edit_role/' . $id);
        return;
    }
    elsif ($submit->{add_actions}) {
        my @actions_to_add = grep length, $request->param('system.actions');
        for my $m (@actions_to_add) {
            $self->exception("Argument", "Module/Action '$m' does not exist")
                unless $system_actions{$m};
        }
        my @new_actions = grep { not $selected{$_} } @actions_to_add;
        for my $new_action (@new_actions) {
            $role_action_rs->create({
                    role_id => $id,
                    action => $new_action,
            });
        }
        $battie->writelog($role, "add_actions");
        $battie->set_local_redirect('/useradmin/edit_role/' . $id);
        return;
    }
    elsif ($submit->{show_actions}) {
        my @modules = $request->param('system.modules');
        my @all_actions;
        for my $module (sort @modules) {
            my $actions = $modules->{$module} or next;
            push @all_actions, (
                "$module/*",
                map {
                    "$module/$_"
                } sort keys %$actions
            );
        }
        my $option_all_actions = [undef];
        @all_actions = grep { not $selected{$_} } @all_actions;
        push @$option_all_actions, map { [$_, $_] } @all_actions;
        $data->{useradmin}->{options}->{actions} = $option_all_actions;
    }
    elsif ($submit->{remove_actions}) {
        my @actions_to_remove = grep length, $request->param('useradmin.actions');
        my %remove = map { $_ => 1 } @actions_to_remove;
        for my $action (@actions_to_remove) {
            my $to_delete = $role_action_rs->find($action);
            next unless $to_delete;
            $to_delete->delete;
        }
        $battie->writelog($role, "remove_actions");
        $battie->set_local_redirect('/useradmin/edit_role/' . $id);
        return;
    }
    else {
        my $option_modules = [undef,
            map {
                [$_, $_]
            } sort grep {
                not $selected{ "$_/*" }
            } (keys %$modules), "*"
        ];
        $data->{useradmin}->{options}->{modules} = $option_modules;
    }

    my $option_actions = [undef, map {
        [$_->id, $_->action]
    } sort { $a->action cmp $b->action } @actions];
    $data->{useradmin}->{options}->{role_actions} = $option_actions;
}

sub useradmin__list_roles {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $role_rs = $schema->resultset('Role');
    my $role_action_rs = $schema->resultset('RoleAction');
    my @roles;
    my $role_search = $role_rs->search(
        {},
        {
            order_by => 'name, rtype',
        },
    );
    while (my $role = $role_search->next) {
        my @actions = $role->actions;
        my $rrole = $role->readonly;
        $rrole->set_actions([map { $_->readonly } @actions]);
        push @roles, $rrole;
    }
    my $request = $battie->get_request;
    $battie->get_data->{useradmin}->{roles} = \@roles;
}

use constant MTIME_GROUP_ACTIONS => 'useradmin/mtime_groups_actions';
use constant MTIME_GROUP_ACTIONS_EXPIRE => 60 * 60 * 24;
sub mtime_groups_actions {
    my ($self, $battie) = @_;
    my $mtime = $battie->from_cache(MTIME_GROUP_ACTIONS);
    unless ($mtime) {
        $mtime = time;
        $battie->to_cache_add(MTIME_GROUP_ACTIONS, $mtime, MTIME_GROUP_ACTIONS_EXPIRE);
    }
    return $mtime;
}

sub fetch_group_ids {
    my ($self, $battie, $group_names) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $search = $schema->resultset('Group')->search({
        rtype => { 'IN' => $group_names },
        });
    my @ids;
    while (my $group = $search->next) {
        push @ids, $group->id;
    }
    return @ids;
}

sub fetch_guest_actions {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $role_rs = $schema->resultset('Role');

    my $cached_actions = $battie->from_cache('useradmin/guest_actions');
    unless ($cached_actions) {
        my ($guest_role) = $battie->module_call(login => 'get_guest_role');
        my $role_list = [$guest_role->readonly];
        my $aroles = $battie->module_call(login => 'get_actions_by_role_ids', $guest_role->id ) || [];
        $aroles = [map { $_->readonly } @$aroles];
        for my $role_action (@$aroles) {
            my $string = $role_action->action;
            my ($page, $act) = split m#/#, $string;
            $cached_actions->{$page}->{$act} = 1;
        }
        $battie->to_cache('useradmin/guest_actions', $cached_actions, 60 * 60 * 12);
        $battie->timer_step("fetch_guest_actions");
    }
    return $cached_actions;
}

sub fetch_all_roles {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $all_roles = $battie->from_cache('useradmin/all_roles');
    unless ($all_roles) {
        my @all = $battie->module_call(login => 'get_all_roles');
        for my $role (@all) {
            my $ro = $role->readonly([qw/ id name rtype /]);
            my @ra = $role->search_related('actions');
            my $actions = [];
            for my $ra (@ra) {
                my $r = $ra->readonly([qw/ id role_id action /]);
                my ($page, $act) = split m#/#, $ra->action;
                $all_roles->{ $role->id }->{ $page }->{ $act } = 1;
            }
        }
        $battie->to_cache('useradmin/all_roles', $all_roles, 60 * 60 * 12);
        $battie->timer_step("fetch_all_roles");
    }
    return $all_roles;
}

sub fetch_group_actions {
    my ($self, $battie, $group_id) = @_;
    my $ck = "useradmin/group_actions_roles/$group_id";
    my $cached = $battie->from_cache($ck);
    unless ($cached) {
        $self->init_db($battie);
        my $schema = $self->get_schema->{user};
        my @group_roles = $schema->resultset('GroupRole')->search({
                group_id => $group_id,
            })->all;
        my %roles;
        my $cached_actions = {};
        my $all_roles = $battie->module_call(useradmin => 'fetch_all_roles');
        for my $group_role (@group_roles) {
            my $role_id = $group_role->role_id;
            $roles{ $role_id } = 1;
            my $module_actions = $all_roles->{ $role_id };
            for my $page (keys %$module_actions) {
                my $actions = $module_actions->{ $page };
                for my $act (keys %$actions) {
                    $cached_actions->{$page}->{$act} = 1;
                }
            }
        }
        $cached->{roles} = \%roles;
        $cached->{actions} = $cached_actions;
        $battie->to_cache($ck, $cached, 60 * 60 * 24);
    }
    return $cached;
}

sub fetch_groups {
    my ($self, $battie) = @_;
    my $ck = "useradmin/groups";
    my $cached = $battie->from_cache($ck);
    unless ($cached) {
        $cached = {};
        $self->init_db($battie);
        my $schema = $self->get_schema->{user};
        my @groups = $schema->resultset('Group')->all;
        for my $group (@groups) {
            my $ro = $group->readonly;
            $cached->{ $ro->id } = [ $ro->name, $ro->rtype ];
        }
        $battie->to_cache($ck, $cached, 60 * 60 * 24);
    }
    return $cached;
}

sub fetch_user_actions {
    my ($self, $battie, $user_id) = @_;
    my $cached = $battie->from_cache("useradmin/user_actions_roles/$user_id");
    unless ($cached) {
        my $cached_actions = {};

        my $all_roles = $battie->module_call(useradmin => 'fetch_all_roles');

        my $user_roles = $battie->module_call(login => 'get_roles_by_user', $user_id);
        my %roles;
        for my $ur (@$user_roles) {
            $roles{ $ur->role_id } = 1;
        }
        $cached->{roles} = \%roles;
        my $roles = [
            @$all_roles{ keys %roles }
        ];
        unless (@$roles) {
            my $guest_actions = $battie->module_call(useradmin => 'fetch_guest_actions');
            $cached->{actions} = $guest_actions;
            $battie->to_cache("useradmin/user_actions_roles/$user_id", $cached, 60 * 3);
            return $cached;
        }
        else {
            for my $role (@$roles) {
                for my $page (keys %$role) {
                    my $actions = $role->{ $page };
                    for my $act (keys %$actions) {
                        $cached_actions->{$page}->{$act} = 1;
                    }
                }
            }
            $cached->{actions} = $cached_actions;
            $battie->to_cache("useradmin/user_actions_roles/$user_id", $cached, 60 * 3);
        }
        $battie->timer_step("fetch_user_actions");
    }
    return $cached;
}

sub useradmin__clear_cache {
    my ($self, $battie) = @_;
    my $groups = $battie->allow->get_groups;
    my $request = $battie->get_request;
    my $role_id = $request->param('role.id');
    my $submit = $request->get_submit;
    if ($submit->{clear}) {
        my @group_ids = $request->param('group_id');
        for my $group_id (@group_ids) {
            next unless $groups->{ $group_id };
            my $ck = "useradmin/group_actions_roles/$group_id";
            $battie->delete_cache($ck);
        }
        $battie->require_token;
        $battie->delete_cache('useradmin/all_roles');
        $battie->delete_cache('useradmin/guest_actions');
        $battie->delete_cache('useradmin/groups');
        $battie->set_local_redirect('/useradmin/clear_cache');
        my $mtime = time;
        $battie->to_cache(MTIME_GROUP_ACTIONS, $mtime, MTIME_GROUP_ACTIONS_EXPIRE);
        return;
    }
    my @groups;
    for my $group_id (keys %$groups) {
        push @groups, { id => $group_id, name => $groups->{ $group_id }->[0] };
    }
    my $data = $battie->get_data;
    $data->{useradmin}->{groups} = \@groups;
}

sub useradmin__create_role {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->get_schema->{user};
    my $role_rs = $schema->resultset('Role');
    my $request = $battie->get_request;
    my $role_id = $request->param('role.id');
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    if (($submit->{create_role} || $submit->{__default}) and not $battie->valid_token) {
        delete $submit->{create_role};
        $data->{useradmin}->{error}->{token} = 1;
    }
    if ($submit->{create_role} || $submit->{__default}) {
        $self->exception("Argument", "Not enough arguments") unless length $role_id;
        $self->exception("Argument", "'$role_id' is not a valid role name")
            unless $schema->valid_rolename($role_id);
        my $exists = $role_rs->find({name => $role_id});
        $self->exception("Argument", "'$role_id' already exists") if $exists;
        my $role = $role_rs->create({
                name => $role_id,
                rtype => 'userdefined',
            });
        #my $allow = $allow_model->create_empty($role_id);
        $battie->get_data->{useradmin}->{role_id} = $role_id;
        $battie->writelog($role);
        $battie->set_local_redirect('/useradmin/list_roles');
    }
}

1;
