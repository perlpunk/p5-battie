#!/usr/bin/perl
use strict;
use warnings;
use Carp qw(carp croak);
use FindBin '$Bin';
use lib "$Bin/../../lib";
use Data::Dumper;
use WWW::Battie;
my $inifile = shift or die "We need an ini file";
my $ini = WWW::Battie::Config::Ini->create($inifile);
my $battie = WWW::Battie->from_ini( $ini );
$battie->module_call(cache => 'clean_cache');
