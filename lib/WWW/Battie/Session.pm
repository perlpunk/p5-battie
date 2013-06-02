package WWW::Battie::Session;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
my @acc = qw/ sid cgis from_cookie ip user token /;
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);

sub from_sid {
    my ($class, $sid, %args) = @_;
    my $schema = $args{schema};
    my $battie = $args{battie};
    my $ck = "login/session/$sid";
#    $battie->timer_step("from_sid start");
    my $session = $battie->from_cache($ck);
    my $sr;
    my $s;
    if ($session) {
        $sr = $session->cgis;
    }
    else {
        $s = $schema->resultset('Session')->find($sid);
        unless ($s) {
            return (WWW::Battie::Session::Dummy->new, 0);
        }
        $sr = $s->readonly;
    }
    my $now = time;
    if ($sr->expires < $now) {
        # expired
        return (WWW::Battie::Session::Dummy->new, 0);
    }
    if ($args{ip} and $sr->remote_addr and $sr->remote_addr ne $args{ip}) {
        my $ip = $sr->remote_addr;
        print STDERR "====== $sid is valid, but from ip $ip, not $args{ip}\n";
        return (WWW::Battie::Session::Dummy->new, 0);
    }
    # valid
    if ($session) {
#        $battie->timer_step("from_sid end cache");
        return ($session, 1);
    }
    # from database
    my $mtime = $s->mtime;
    $mtime += 60 * 3;
    if ($mtime <= $now) {
        # need to update
        my $expires = $now + 60 * 60;
        $s->mtime($now);
        $s->expires($expires);
        $s->update;
    }

    my $bless = $sr->user_id ? $class : 'WWW::Battie::Session::Guest';
    my $self = $bless->new({
            sid => $sid,
            cgis => $sr,
            from_cookie => $args{from_cookie},
#            %args,
    });
#    $battie->timer_step("from_sid end db");
    return ($self, 0);
}

sub hide_show {
    my ($self, %args) = @_;
    my $schema = $args{schema};
    my $hide = $args{hide} ? 1 : 0;
    my $sr = $self->cgis;
    my $data = $sr->data;
    my $s = $schema->resultset('Session')->find($sr->id);
    if (($hide and not $data->{hidden}) or (!$hide and $data->{hidden})) {
        $data->{hidden} = $hide;
        $sr->set_data($data);
        $s->data($data);
        $s->update;
    }
}

sub update_terms {
    my ($self, %args) = @_;
    my $schema = $args{schema};
    my $terms = $args{terms};
    my $sr = $self->cgis;
    my $data = $sr->data;
    my $s = $schema->resultset('Session')->find($sr->id);
    for my $key (keys %$terms) {
        $data->{terms}->{$key} = $terms->{$key}->start_date->epoch;
    }
    $sr->set_data($data);
    $s->data($data);
    $s->update;
}

sub terms_to_accept {
    my ($self) = @_;
    my $sr = $self->cgis;
    my $t = $sr->terms_to_accept;
    return $sr->terms_to_accept;
}

sub update_user {
    my ($self, %args) = @_;
    bless $self, 'WWW::Battie::Session';
    my $schema = $args{schema};
    my $sr = $self->cgis;
    my $data = $sr->data;
    my $sid = $sr->id;
    warn __PACKAGE__.':'.__LINE__.": update_user sid $sid\n";
    my $s = $schema->resultset('Session')->find($sid);
    my $ck = "login/session/$sid";
    my $battie = $args{battie};
    $battie->delete_cache($ck);
    $s->user_id($args{userid});
    $data->{remote_addr} = $args{ip};
    $data->{token} = '';
    $sr->set_data($data);
    $s->data($data);
    $s->update;
    $self->set_user($args{user});
    return $self;
}

sub create {
    my ($class, %args) = @_;
    my $schema = $args{schema};
    my $s;
    my $created = 0;
    my $tried = 0;
    my $now = time;
#    my $expires = DateTime->now->add( minutes => 60 );
    my $expires = $now + 60 * 60;
    my $data = {
        token => $args{token},
        remote_addr => $args{ip},
    };
    my $id;
    while (!$created) {
        last if $tried++ > 3;
        $id = $schema->generate_sid;
#        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$id], ['id']);
        eval {
            $s = $schema->resultset('Session')->create({
                user_id => $args{userid},
                data    => $data,
                id      => $id,
                expires => $expires,
                ctime   => $now,
                mtime   => $now,
            });
        };
        if ($@) {
            warn __PACKAGE__.':'.__LINE__.": !!!!!!!!!! $@\n";
        }
        else {
            $created = 1;
        }
    }
    my $sid = $id;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\%args], ['args']);
    my $sr = $s->readonly;
    my $self = $class->new({
            sid => $sid,
            cgis => $sr,
            user => $args{user},
#            %args,
        });
    return $self;
}

sub delete {
    my ($self, %args) = @_;
    my $schema = $args{schema};
    my $cgis = $self->get_cgis;
    $schema->resultset('Session')->find($cgis->id)->delete;
    #print STDERR "deleted session!\n";
}

sub userid {
    my ($self) = @_;
    my $cgis = $self->get_cgis;
    my $userid = $cgis->user_id;
    return $userid;
}

sub create_cookie {
    my ($self, $response, %args) = @_;
    $response->add_cookie({
        -name  =>'battie_sid',
        -value => {
            id => $self->get_sid,
       },
       -expires => '+60m',
    });
    if ($self->cgis->remote_addr) {
        $response->add_cookie({
            -name    =>'battie_bind_to_ip',
            -value   => 1,
            -expires => '+2M',
        });
    }
}

sub expire_session {
    my ($self, $response, %args) = @_;
    my $sid = $self->get_sid;
    $self->set_user(undef);
    return unless $sid;
	#warn __PACKAGE__.':'.__LINE__.": !!!!!!!!!!! $args{schema}\n";
    $self->delete(%args);
    $response->add_cookie({
        -name=>'battie_sid',
        -value => {
            id => $sid,
       },
       -expires => '-2h',
    });
}

sub dummy { 0 }

{
package WWW::Battie::Session::Dummy;

our @ISA = 'WWW::Battie::Session';

sub userid {
    return '';
}

sub create_cookie { }
sub dummy { 1 }
}

{
package WWW::Battie::Session::Guest;

our @ISA = 'WWW::Battie::Session';

sub userid {
    return '';
}
sub dummy { 0 }

}
