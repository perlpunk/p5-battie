#!/usr/bin/perl
use strict;
use warnings;

use CGI::Fast;
use FindBin qw($RealBin);


# Remove this guesswork if you want to set your own locations
my $inifile = my $libdir = $RealBin;
$inifile =~ s{ /bin/? \z } {/conf/battie.ini}x;
$libdir  =~ s{ /bin/? \z } {/lib}x;
use lib;
lib->import($libdir);


$WWW::Battie::DEBUG = 0;

require WWW::Battie;
my $ini = WWW::Battie::Config::Ini->create($inifile);
my $battie = WWW::Battie->from_ini( $ini );

while (my $cgi = CGI::Fast->new) {
    if (0) {
        # if you need to switch the site off
        print "Content-Type: text/plain\n\nmaintenance";
        next;
    }

    eval {
        $battie->run(cgi => $cgi);
        my ($out, $mode) = $battie->output;
        binmode STDOUT, $mode;
        print $out;
        $battie->set_session(undef);
    };
    if ($@) {
        warn $@;
        print <<'EOM';
Content-Type: text/plain

There was an error. Please see logfile.
EOM
    }
}
