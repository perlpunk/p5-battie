package WWW::Battie::Allow;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/ actions roles groups /);
use Time::HiRes qw(gettimeofday tv_interval);

my %groups_cache;
my %actions_cache;
my %cache_mtime;
my %cache_mtime_checked;
my %group_ids_to_cache;

sub create_from_user {
    my ($self, $battie, $user) = @_;
    $battie->timer_step("create_from_user start");
    my $user_id = $user ? $user->id : 0;
    my $possible_actions = $battie->get_functions;
    my %allowed;
    my $aroles = [];
    my $role_list = {};
    $battie->module_call(login => 'load_db');
    my $group_ids_to_cache = $group_ids_to_cache{ $battie };
    unless ($group_ids_to_cache) {
        # TODO configure in battie.ini
        my @group_ids = $battie->module_call(useradmin => 'fetch_group_ids', [qw/ guest initial user admin /]);
        $group_ids_to_cache = { map { $_ => 1 } @group_ids };
        $group_ids_to_cache{ $battie } = $group_ids_to_cache;
    }
#    $battie->timer_step("fetch_groups start");
    my $last_mtime = $cache_mtime{$battie} || 0;
    my $mtime;
    if (($cache_mtime_checked{$battie}||0)+60 < time) {
        $mtime = $battie->module_call(useradmin => 'mtime_groups_actions');
        $cache_mtime_checked{$battie} = time;
    }
    else {
        $mtime = $last_mtime;
    }
    if ($mtime > $last_mtime) {
        delete $groups_cache{$battie};
        delete $actions_cache{$battie};
        $cache_mtime{$battie} = $mtime;
    }
    my $groups;
    unless ($groups_cache{$battie}) {
        $groups = $battie->module_call(useradmin => 'fetch_groups');
        $groups_cache{$battie} = $groups;
    }
    else {
        $groups = $groups_cache{$battie};
    }
#    $battie->timer_step("fetch_groups end");
    unless ($user_id) {
        # we are guest
        my $guest_actions;
        unless ($actions_cache{$battie}->{guest}) {
            $guest_actions = $battie->module_call(useradmin => 'fetch_guest_actions');
            $actions_cache{$battie}->{guest} = $guest_actions;
        }
        else {
            $guest_actions = $actions_cache{$battie}->{guest};
        }
#        $battie->timer_step("fetch_guest_actions end");
        %allowed = %$guest_actions;
    }
    else {
        my $group_id = $user->group_id;
        my $extra_roles = $user->extra_roles;
        my $actions_roles;
        if ($group_id and not $extra_roles) {
            if ($group_ids_to_cache{ $battie}->{ $group_id }) {
                $actions_roles = $actions_cache{$battie}->{$group_id}->{actions_roles};
                unless ($actions_roles) {
                    $actions_roles = $battie->module_call(useradmin => 'fetch_group_actions', $group_id);
                    $actions_cache{$battie}->{$group_id}->{actions_roles} = $actions_roles;
                }
            }
            else {
                $actions_roles = $battie->module_call(useradmin => 'fetch_group_actions', $group_id);
            }
#            $battie->timer_step("fetch_group_actions end");
        }
        else {
            $actions_roles = $battie->module_call(useradmin => 'fetch_user_actions', $user_id);
        }
        $role_list = $actions_roles->{roles};
        my $user_actions = $actions_roles->{actions};
        unless (keys %$user_actions) {
            $user_actions = $battie->module_call(useradmin => 'fetch_guest_actions');
        }
        %allowed = %$user_actions;
    }

    my $allow = WWW::Battie::Allow->create(\%allowed, $possible_actions);
    $allow->set_groups($groups);
    $allow->set_roles($role_list);
    $battie->timer_step("create_from_user end");
    return $allow;
}

sub create {
    my ($class, $allowed, $possible_actions) = @_;
    my $actions = {};
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$allowed], ['allowed']);
    for my $module (keys %$possible_actions) {
        #warn __PACKAGE__." module $module $allowed->{$module} $allowed->{'*'}\n";
        my $allowed_actions = $allowed->{'*'} || $allowed->{$module};
        if ($allowed_actions) {
            $actions->{$module} = {};
            for my $action (keys %{ $possible_actions->{$module}->{actions} }) {
                #warn __PACKAGE__." $module-$action $allowed_actions->{'*'}\n";
                if ($allowed_actions->{'*'} or $allowed_actions->{$action}) {
                    $actions->{$module}->{$action} = 1;
                }
            }
        }
    }
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$actions], ['actions']);
    my $self = $class->new({
        actions => $actions,
    });
}

sub can_do {
    my ($self, $module, $action) = @_;
    my $actions = $self->get_actions;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$actions], ['actions']);
    return unless exists $actions->{$module};
    $action =~ s/^ajax_//;
    return unless $actions->{$module}->{$action};
    return 1;
}

1;
