package WWW::Battie::Handler;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);

use Apache::SizeLimit;
use Apache::Constants qw(:common);
use Time::HiRes qw(gettimeofday tv_interval);
use WWW::Battie;

my %battie;

my %log_filehandles;

sub handler {
    #$ENV{DBIC_TRACE}=1;
    my $r = shift;
    my ($size, $shared) = Apache::SizeLimit->_check_size();
    # TODO for load balancers
    if (0) {
		repair_ip();
    }

    my $start_time = [gettimeofday];
    my $inifile = $r->dir_config->get('inifile');
    my $battie = $battie{$inifile};
    unless ($battie) {
        my $ini = WWW::Battie::Config::Ini->create($inifile);
        $battie = WWW::Battie->from_ini( $ini );
        $battie{$inifile} = $battie;
        my $elapsed = tv_interval ( $start_time );
        warn " Battie->new() took $elapsed seconds\n";
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
    {
        my ($out, $mode) = $battie->output;
        #binmode STDOUT, ":encoding(utf-8)";
        binmode STDOUT, $mode;
        eval {
            print $out if defined $out;
        };
        if ($@) {
            # e.g. "Software caused connection abort"
            warn "ERROR in print: $@";
        }
    }
    $battie->timer_step("after output");
    $battie->set_session(undef);
    ($size, $shared) = Apache::SizeLimit->_check_size();
    @$actionlogs{qw/ PSIZE PSHARED /} = ($size, $shared);
    $actionlogs->{IP} = $ENV{REMOTE_ADDR};
    my $time = time;
    my $ts = localtime($time);
    $actionlogs->{TS} = $ts;
    $actionlogs->{EPOCH} = $time;
	my $log_fh = create_logfh($battie, $inifile, \%log_filehandles);
    my $elapsed = tv_interval ( $start_time );
    $actionlogs->{TIME} = sprintf "%0.2f", $elapsed * 1000;
    $actionlogs->{PID} = $$;
    $battie->clear;
    print $log_fh $battie->print_action_log($actionlogs) . $/;

    return OK;
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

__END__

=pod

=head1 NAME

WWW::Battie::Handler - The Battie mod_perl Handler

=cut

