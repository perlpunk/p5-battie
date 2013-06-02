#!/usr/bin/perl
use strict;
use warnings;
use Carp qw(carp croak);
use Data::Dumper;
use FindBin '$Bin';
use lib "$Bin/../../lib";
use WWW::Battie;
my $inifile = shift or die "We need an ini file";
my $ini = WWW::Battie::Config::Ini->create($inifile);
my $battie = WWW::Battie->from_ini( $ini );
my $deleted = $battie->module_call(login => 'clean_expired_sessions');
print "Deleted $deleted expired sessions\n";

