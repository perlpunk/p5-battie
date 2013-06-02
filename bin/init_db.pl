#!/usr/bin/perl
use strict;
use warnings;
use Carp qw(carp croak);
use Data::Dumper;
use WWW::Battie;
my $inifile = shift or die "We need an ini file";
my $ini = WWW::Battie::Config::Ini->create($inifile);
my $battie = WWW::Battie->from_ini( $ini );
my $version = WWW::Battie->VERSION;
my %list;
my $m = $battie->get_modules;
#warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$m], ['m']);
print "Loading DB-classes...\n";
for my $name (keys %$m) {
    my $module = $m->{$name};
    #print "module $name @{[ ref $module ]}\n";
    print "module $name\n";
    if ($module->isa('WWW::Battie::Module::Model')) {
        $battie->module_call($name => 'init_db');
        my $schema = $battie->sub_call($name => 'schema');
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$schema], ['schema']);
        $list{$_} = $schema->{$_} for keys %$schema;
    }
}

print "Creating admin role if it doesn't exist...\n";
my $schema = $list{user};
my $admin_role = $schema->resultset('Role')->find({rtype => 'admin'});
unless ($admin_role) {
    $admin_role = $schema->resultset('Role')->create({
        rtype => 'admin',
        name  => 'Admin',
    });
}
print "Creating guest role if it doesn't exist...\n";
my $guest_role = $schema->resultset('Role')->find({rtype => 'guest'});
unless ($guest_role) {
    $guest_role = $schema->resultset('Role')->create({
        rtype => 'guest',
        name  => 'Guest',
    });
}
print "Creating user role if it doesn't exist...\n";
my $user_role = $schema->resultset('Role')->find({rtype => 'user'});
unless ($user_role) {
    $user_role = $schema->resultset('Role')->create({
        rtype => 'user',
        name  => 'User',
    });
}

print "Creating initial user role if it doesn't exist...\n";
my $init_role = $schema->resultset('Role')->find({rtype => 'initial'});
unless ($init_role) {
    $init_role = $schema->resultset('Role')->create({
        rtype => 'initial',
        name  => 'Initial',
    });
}

print "Creating openid user role if it doesn't exist...\n";
my $openid_role = $schema->resultset('Role')->find({rtype => 'openid'});
unless ($openid_role) {
    $openid_role = $schema->resultset('Role')->create({
        rtype => 'openid',
        name  => 'Openid',
    });
}


print "Creating role-actions */* for admin role if none exist...\n";
my $ra = $schema->resultset('RoleAction')->find({
        role_id => $admin_role->id,
        action => '*/*',
    });
unless ($ra) {
    $ra = $schema->resultset('RoleAction')->create({
            role_id => $admin_role->id,
            action => '*/*',
        });
}

print "Creating groups...\n";

my @groups = (
    [guest      => 'Guest'      , $guest_role,],
    [initial    => 'Initial'    , $guest_role, $init_role],
    [user       => "User"       , $guest_role, $init_role, $user_role],
    [admin      => 'Admin'      , $admin_role],
);
my %groups;
for my $group (@groups) {
    my ($rtype, $name, @roles) = @$group;
    my $g = $schema->resultset('Group')->find({
            rtype => $rtype,
        });
    if ($g) {
        print "Group $rtype exists\n";
    }
    else {
        print "Creating group $rtype\n";
        $g = $schema->resultset('Group')->create({
                name => $name,
                rtype => $rtype,
            });
    }
    $groups{$rtype} = $g;
    for my $role (@roles) {
        my $rg = $schema->resultset('GroupRole')->find({
                role_id => $role->id,
                group_id => $g->id,
            });
        if ($rg) {
            print "role @{[ $role->rtype ]} exists\n";
        }
        else {
            print "Creating role @{[ $role->rtype ]}\n";
            $rg = $schema->resultset('GroupRole')->create({
                    role_id => $role->id,
                    group_id => $g->id,
                });
        }
    }

}


#print "Creating role-actions login/* for guest role if none exist...\n";
#my $rg = $schema->resultset('RoleAction')->find({
#        role_id => $guest_role->id,
#        action => 'login/*',
#    });
#unless ($rg) {
#    $rg = $schema->resultset('RoleAction')->create({
#            role_id => $guest_role->id,
#            action => 'login/*',
#        });
#}

print "Creating default role-actions per module...\n";
my %default_roles;
$default_roles{guest} = $guest_role;
$default_roles{admin} = $admin_role;
$default_roles{user} = $user_role;
$default_roles{initial} = $init_role;
$default_roles{openid} = $openid_role;
{

    for my $name (keys %$m) {
        my $module = $m->{$name};
        #print "module $name @{[ ref $module ]}\n";
        #print "module $name\n";
        if ($module->can('default_actions')) {
            my $actions = $battie->module_call($name => 'default_actions');
            #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$actions], ['actions']);
            for my $k (keys %$actions) {
                my $def_role = $default_roles{$k};
                unless ($def_role) {
                    $def_role = $schema->resultset('Role')->find({rtype => $k});
                    unless ($def_role) {
                        print "Creating role $k...\n";
                        $def_role = $schema->resultset('Role')->create({
                            rtype => $k,
                            name  => $k,
                        });
                    }
                    $default_roles{$k} = $def_role;
                }
                my $act = $actions->{$k};
                for my $item (@$act) {
                    my $def = {
                        role_id => $def_role->id,
                        action => "$name/$item",
                    };
                    my $ra = $schema->resultset('RoleAction')->find($def);
                    warn __PACKAGE__.':'.__LINE__.": creating $name/$item for $k\n" unless $ra;
                    $ra ||= $schema->resultset('RoleAction')->create($def);

                }

            }
        }
    }
}


#print "Creating role-actions userprefs/* for user role if none exist...\n";
#my $ru = $schema->resultset('RoleAction')->find({
#        role_id => $user_role->id,
#        action => 'userprefs/*',
#    });
#unless ($ru) {
#    $ru = $schema->resultset('RoleAction')->create({
#            role_id => $user_role->id,
#            action => 'userprefs/*',
#        });
#}
#print "Creating role-actions userprefs/* for initial user role if none exist...\n";
#for my $action (qw(userprefs/start userprefs/set_password)) {
#    my $iru = $schema->resultset('RoleAction')->find({
#            role_id => $init_role->id,
#            action => $action,
#        });
#    unless ($iru) {
#        $iru = $schema->resultset('RoleAction')->create({
#                role_id => $init_role->id,
#                action => $action,
#            });
#    }
#}
print "Name of admin user: ['admin'] ";
chomp(my $nick = <STDIN>);
$nick ||= 'admin';
print "Password of admin user (leave empty if you want to set it later or have already set it): ";
chomp(my $pass = <STDIN>);
$pass ||= '';

print "Creating admin user '$nick' if it doesn't exist...\n";
my $user = $schema->resultset('User')->find({
        nick => $nick,
    });
unless ($user) {
    $user = $schema->resultset('User')->create({
            nick => $nick,
            ctime => undef,
            active => 1,
            group_id => $groups{admin}->id,
        });
}
if (length $pass) {
    my $crypted = $schema->encrypt($pass);
    $user->password($crypted);
    $user->update;
}


my $ur = $schema->resultset('UserRole')->find({
        user_id => $user->id,
        role_id => $admin_role->id,
    });
unless ($ur) {
    $ur = $schema->resultset('UserRole')->create({
            user_id => $user->id,
            role_id => $admin_role->id,
        });
}

print "Creating default page if it doesn't exist\n";
my $cschema = $list{content};
my $exists = $cschema->resultset('Page')->search({
    url => "home",
})->single;
unless ($exists) {
    my $text = <<'EOM';
This is the welcome page of your battie installation. If you can
see this, you got it working =)
EOM
    my $page = $cschema->resultset('Page')->create({
        title => "Welcome",
        url => "home",
        text => $text,
        parent => 0,
        position => 1,
        ctime => undef,
    });
}
print "Done.\n";
exit;

