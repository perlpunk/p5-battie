package WWW::Battie::Handler2;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use Apache2::RequestRec ();
use APR::Table;
use Apache2::RequestIO ();

use Apache2::SizeLimit;

use Apache2::Const -compile => qw(OK);
use Time::HiRes qw(gettimeofday tv_interval);
use WWW::Battie;
use File::Spec;

my %battie;

my %log_filehandles;

my $maintenance_file = '';
my %maintenance = (
    maintenance => 0,
    time => 0,
);

sub handler {
    #$ENV{DBIC_TRACE} = 1;
    my $r = shift;
    my ($size, $shared) = $Apache2::SizeLimit::HOW_BIG_IS_IT->();

#    use Linux::Smaps;
#    my $map = Linux::Smaps->new($$);
#    my $sizes = sprintf "PID $$ size: %d shared_clean: %d shared_dirty: %d",
#    $map->size,
#    $map->shared_clean,
#    $map->shared_dirty;
#    warn __PACKAGE__.':'.__LINE__.": $sizes\n";

    # TODO for load balancers
    if (0) {
		repair_ip();
    }
#    if ($ENV{REMOTE_ADDR} =~ m/^(127\.0)/
#            and $ENV{PATH_INFO} =~ m{^/poard/message}) {
#        warn "FORBIDDEN: $ENV{REMOTE_ADDR} PATH: $ENV{PATH_INFO}\n";
#        $r->content_type('text/plain');
#        $r->status(403);
#        print "Forbidden\n";
#        return Apache2::Const::OK;
#    }

    my $start_time = [gettimeofday];
    my $inifile = $r->dir_config->get('inifile');
    my $battie = $battie{$inifile};
    unless ($battie) {
        my $ini = WWW::Battie::Config::Ini->create($inifile);
        $battie = WWW::Battie->from_ini( $ini );
        $maintenance_file = $battie->get_paths->{maintenance_file};
        $battie{$inifile} = $battie;
        my $elapsed = tv_interval ( $start_time );
        warn " Battie->new() took $elapsed seconds\n";
    }

    my $now = time;
    if ($maintenance_file and ($maintenance{time} + 5) < $now) {
        if ($maintenance{maintenance} and not -f $maintenance_file) {
            $maintenance{maintenance} = 0;
        }
        elsif (not $maintenance{maintenance} and -f $maintenance_file) {
            $maintenance{maintenance} = 1;
        }
        $maintenance{time} = $now;
    }
    if ($maintenance{maintenance}) {
        $r->headers_out->set('Retry-After' => 30);
        $r->content_type('text/plain');
        $r->status(503);
        print "Server maintenance, try again later\n";
        warn __PACKAGE__.':'.__LINE__.": maintenance ($ENV{REQUEST_URI})\n";
        return Apache2::Const::OK;
    }

    $battie->clear;
    if ($battie->get_conf->{enable_https}) {
        my $table = $r->headers_in();
        my $val = $table->get('Front-End-Https');
        if ($val) {
            $battie->set_https(1);
        }
    }
    $battie->set_logs({ action => {}});
    my $actionlogs = $battie->logs->{action};
    @$actionlogs{qw/ PSIZE_BEFORE PSHARED_BEFORE /} = ($size, $shared);
    $battie->timer_start("start");
    $battie->run;
    $actionlogs->{IP} = $ENV{REMOTE_ADDR};
    $actionlogs->{PID} = $$;
    my ($out, $mode) = $battie->output;
    my $elapsed = tv_interval ( $start_time );

        binmode STDOUT, $mode;
        eval {
            print $out if defined $out;
        };
        if ($@) {
            # e.g. "Software caused connection abort"
            warn "ERROR in print: $@";
        }

    $battie->timer_step("after output");
    $battie->set_session(undef);
    ($size, $shared) = $Apache2::SizeLimit::HOW_BIG_IS_IT->();
    @$actionlogs{qw/ PSIZE PSHARED /} = ($size, $shared);
    my $time = time;
    my $ts = localtime($time);
    $actionlogs->{TS} = $ts;
    $actionlogs->{EPOCH} = $time;
    my $log_fh = create_logfh($battie, $inifile, \%log_filehandles);
    $actionlogs->{TIME} = sprintf "%0.2f", $elapsed * 1000;
    $battie->clear;
    print $log_fh $battie->print_action_log($actionlogs) . $/;

    return Apache2::Const::OK;

}

sub create_logfh {
	my ($battie, $inifile, $filehandles) = @_;
	my $log_fh = $filehandles->{ $inifile };
    if ($log_fh) {
    }
    else {
        if (my $path = $battie->get_paths->{actionlog}) {
            unless (File::Spec->file_name_is_absolute($path)) {
                $path = File::Spec->catfile($battie->get_paths->{serverroot}, $path);
            }
            open $log_fh, ">>", $path
                or die "ACTIONLOG $path is not writeable: $!";
            my $old_fh = select $log_fh;
            $|++;
            select $old_fh;
			$log_filehandles{ $inifile } = $log_fh;
        }
        else {
            $log_fh = \*STDERR;
        }
    }
	return $log_fh;
}

# for load balancers
sub repair_ip {
	my $ff = $ENV{HTTP_FORWARDED_FOR} || $ENV{HTTP_X_FORWARDED_FOR} || $ENV{HTTP_CLIENT_IP};
	my $host = $ENV{REMOTE_ADDR};
	if ($host eq $ENV{SERVER_ADDR} and $ff) {
		my (@forwarded) = split m/\s*,\s*/, $ff;
		#print STDERR "====== forwarded: @forwarded\n";
		$ENV{REMOTE_ADDR} = pop @forwarded;
		$ENV{HTTP_FORWARDED_FOR} = join ",", @forwarded;
	}
}

1;

