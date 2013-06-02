package WWW::Battie::Modules::MemCache;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module';
use base 'Class::Accessor::Fast';
my $class;
BEGIN {
    if (eval "use Cache::Memcached::Fast; 1") {
        $class = 'Cache::Memcached::Fast';
    }
    elsif (eval "use Cache::Memcached; 1") {
        $class = 'Cache::Memcached';
    }
    else {
        die "No memcacheed module found";
    }
}
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/ servers cache namespace /);
my %functions = (
    functions => {
        cache => {
            start => 1,
            clear => 1,
            init => {
                on_run => 1,
            },
        },
    },
);
sub functions { %functions }

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        return {
            link => ['cache', 'start'],
            text => 'Cache',
        };
    };
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$args], ['args']);
    my $servers = $args->{SERVERS};
    my $cache_ns = $args->{CACHE_NAMESPACE};
    unless (length $cache_ns) {
        warn __PACKAGE__.':'.__LINE__.": Please set a CACHE_NAMESPACE for Module WWW::Battie::Modules::MemCache\n";
        $cache_ns = 'BAT';
    }
    my @servers = split /,/, $servers;
    my $self = $class->new({
            servers => \@servers,
            namespace => $cache_ns,
        });
    $self->cache__init;
    return $self;
}

sub cache__init {
    #sleep 3;
    my ($self) = @_;
    my $cache = $self->get_cache;
    #warn __PACKAGE__." ============= calling cache__init ($cache)\n";
    return if $cache;
    my $servers = $self->get_servers;
    $cache = $class->new({
            servers => $servers,
            namespace => $self->get_namespace,
            #debug => 0,
        });
    $self->set_cache($cache);
}

sub delete_cache {
    my ($self, $battie, $key) = @_;
    return if $key =~ tr{a-zA-Z0-9_/}{}c;
    $key =~ s{ ^/ }{}x;
    my $cache = $self->get_cache;
    $cache->delete($key);
}

sub from_cache {
    my ($self, $battie, @keys) = @_;
    #warn __PACKAGE__.':'.__LINE__.": =========== from_cache($key)\n";
	if (@keys > 1) {
		my $hash = $self->get_cache->get_multi(@keys);
		return $hash;
	}
	elsif (ref $keys[0]) {
		my $hash = $self->get_cache->get_multi(@{ $keys[0] });
		return $hash;
	}
    return if $keys[0] =~ tr{a-zA-Z0-9_/}{}c;
    $keys[0] =~ s{ ^/ }{}x;
    return $self->get_cache->get($keys[0]);
}

sub cache_add {
    my ($self, $battie, $key, $data, $expire) = @_;
    #return;
    return if $key =~ tr{a-zA-Z0-9_/}{}c;
    #warn __PACKAGE__.':'.__LINE__.": add($key, $expire)\n";
    $key =~ s{ ^/ }{}x;
    my $cache = $self->get_cache;
    $cache->add($key, $data, $expire);
}

sub cache {
    my ($self, $battie, $key, $data, $expire) = @_;
    #return;
    return if $key =~ tr{a-zA-Z0-9_/}{}c;
    #warn __PACKAGE__.':'.__LINE__.": set($key, $expire)\n";
    $key =~ s{ ^/ }{}x;
    my $cache = $self->get_cache;
    $cache->set($key, $data, $expire);
}

sub cache__start {
    my ($self, $battie) = @_;
    my $data = $battie->get_data;
    $data->{cache}->{module} = __PACKAGE__;
    $data->{cache}->{stats} = {
        servers => $self->get_servers,
        statistics => $self->get_cache->stats,
    };
}

sub cache__clear {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $submit = $request->get_submit;
    if ($submit->{clear} and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{clear}) {
        $self->get_cache->flush_all;
        $battie->set_local_redirect("/cache/start");
    }
}

1;
