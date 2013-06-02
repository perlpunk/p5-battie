package WWW::Battie::Modules::Log;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module::Model';
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/ geo_ip /);
use WWW::Battie::Pager;
use WWW::Battie::Sorter;
my %functions = (
    functions => {
        log => {
            start => 1,
        },
    },
);
sub functions { %functions }

sub model {
    log => 'WWW::Battie::Schema::Log',
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        return {
            link => ['log', 'start'],
            text => 'View Log',
        };
    };
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$args], ['args']);
    my $geoip = $args->{GEOIP};
    if ($geoip and -f $geoip) {
        require Geo::IP;
        #Geo::IP->import;
        $geoip = Geo::IP->open( $geoip, Geo::IP::GEOIP_STANDARD() );
    }
    my $self = $class->new({
            geo_ip => $geoip,
        });
}


sub log__start {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema  = $self->get_schema->{log};
    my $request = $battie->get_request;
    my $page = $request->param('p') || 1;
    # make that a configuration variable or settable by user
    my $rows = 30;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$pager], ['pager']);
    #$ENV{DBIC_TRACE} = "3=/tmp/dbic_trace";
    my $sort = $request->param('so');
    my $new_sort = $request->param('sort');
    my $sorter = WWW::Battie::Sorter->from_cgi({
            cgi => $sort,
            new => $new_sort,
            fields => [qw(userid module action)],
            uri => $battie->self_url . '/log/start?p='.$page.';so=%s',
        });
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$sorter], ['sorter']);
    $sorter->to_template;
    my $param = $sorter->param;
    my ($search, $count_ref) = $schema->count_search(LogEntry =>
        undef,
        {
                order_by => 'ctime desc',
                page => $page,
                rows => $rows,
        }
    );
    my @entries;
    while (my $entry = $search->next) {
        push @entries, $entry->readonly;
    }
    my $count = $count_ref->();
    my $pager = WWW::Battie::Pager->new({
            items_pp => $rows,
            total_count => $count,
            before => 3,
            after => 3,
            current => $page,
            link => $battie->self_url . '/log/start?p=%p;so=' . $param,
            title => '%p',
        })->init;
    $battie->get_data->{log}->{entries} = \@entries;
    $battie->get_data->{log}->{pager} = $pager;
    $battie->get_data->{log}->{sorter} = $sorter;
}

sub writelog {
    my ( $self, $battie, $object, $comment ) = @_;
    $self->init_db($battie);
    my $schema  = $self->get_schema->{log};
    my $request = $battie->get_request;
    my $mod     = $request->get_page;
    my $action  = $request->get_action;
    my $ip      = $ENV{REMOTE_ADDR};
    my $gi = $self->get_geo_ip;
    my $country;
    my $city;
    if ($gi) {
        my $r = $gi->record_by_addr( $ip );
        if ($r) {
            $country = $r->country_code;
            $city = $r->city;
        }
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$country], ['country']);
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$city], ['city']);
    }

    my $ff      = $ENV{HTTP_CLIENT_IP} || $ENV{HTTP_FORWARDED_FOR};
    my $ref     = $ENV{HTTP_REFERER};
    #warn __PACKAGE__." $_: $ENV{$_}\n" for sort keys %ENV;
    #return;
    my $entry = $schema->resultset('LogEntry')->create({
            user_id => $battie->get_session->userid || 0,
            comment => $comment,
            object_type => ref $object,
            object_id => $object ? $object->id : undef,
            ip => $ip,
            country => $country,
            city => $city,
            forwarded_for => $ff,
            ctime => undef,
            module => $mod,
            action => $action,
            referrer => $ref,
        });
}

sub get_logs {
    my ($self, $battie, $object, $args) = @_;
	$args ||= {};
    return [] unless $object;
    $self->init_db($battie);
    my $schema  = $self->get_schema->{log};
    my $search = $schema->resultset('LogEntry')->search({
            object_type => ref $object,
            object_id => $object->id,
        });
    my @logs;
	my %actions;
	if ($args->{actions}) {
		@actions{ @{ $args->{actions} } } = ();
	}
    while (my $log = $search->next) {
		if (keys %actions) {
			my $action = $log->module . '/' . $log->action;
			next unless exists $actions{$action};
		}
        push @logs, $log;
    }
    return \@logs;
}


1;
