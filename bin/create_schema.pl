#!/usr/bin/perl
use strict;
use warnings;
use WWW::Battie;
use Getopt::Long;
my $inifile = shift or die "We need an ini file";
my $ini = WWW::Battie::Config::Ini->create($inifile);
for my $model (keys %{ $ini->{models} }) {
    $ini->{models}->{$model}->{TABLE_PREFIX} = 'TABLE_PREFIX';
}
my $result = GetOptions(
    complete => \my $complete,
);
#warn Data::Dumper->Dump([\$hash], ['hash']);
my $battie = WWW::Battie->from_ini( $ini );
my $version = WWW::Battie->VERSION;
my %list;
my $m = $battie->get_modules;
#warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$m], ['m']);
for my $name (keys %$m) {
    my $module = $m->{$name};
    #print "module $name $module\n";
    print "loading module $name\n";
    if ($module->isa('WWW::Battie::Module::Model')) {
        $battie->module_call($name => 'init_db');
        my $schema = $battie->sub_call($name => 'get_schema');
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$schema], ['schema']);
        $list{ $_ } = $schema->{$_} for keys %$schema;
    }
}

for my $dbs (qw/ MySQL PostgreSQL /) {
#for my $dbs (qw/ MySQL /) {
    my $cfh;
    my $cfile = "battie_schema_${version}_$dbs.sql";
    if ($complete) {
        open $cfh, ">", $cfile or die $!;
        print $cfh "-- Schema for Battie $version\n\n";
    }
    for my $schema_name (keys %list) {
        #for my $schema_name ('gallery') {
        my $schema = $list{$schema_name};
#        my @test = $schema->storage->deployment_statements(
#            $schema, $dbs,
#            {
#                mysql_character_set => 'utf-8',
#            }
#        );
#        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@test], ['test']);
        my $deploy = $schema->storage->deployment_statements(
            $schema, $dbs,
            {
                mysql_character_set => 'utf-8',
            }
        );
        if ($dbs eq 'PostgreSQL') {
            # postgres has no ENUMs
            $deploy =~ s/ enum\(.*?\) / varchar(16) /g;
            # sql creator for Postgres seems to have a bug
            $deploy =~ s/^--CREATE /CREATE /gm;
            $deploy =~ s/ (tiny|small|big)?int(\(\d+\))? / integer /g;
            $deploy =~ s/ (big|small)int\b/ integer/g;
            $deploy =~ s/ enum\(.*?\)/ char(1)/g;
        }
        my $v = $schema->VERSION;
        my $fname = $schema_name;
        unless ($v) {
            warn "$schema_name has no version, defaulting to 0.01";
            $v = '0.01';
        }
        $fname =~ s/::/_/g;
        $fname = "schema_$fname" . "_" . $v;
        if ($complete) {
            print $cfh "--\n--\n-- schema $fname\n--\n--\n";
            print $cfh $deploy;
            next;
        }
        $fname .= "_$dbs.sql";
        if (-f $fname) {
            print "schema for $schema_name at $fname exists\n";
        }
        else {
            #print $deploy;
            open my $fh, ">", $fname;
            #print $schema->storage->deployment_statements($schema, "MySQL");
            # mysql_character_set
            print $fh $deploy;
            close $fh;
            print "Generated schema for $schema_name at $fname\n";
        }
    }
    if ($complete) {
        close $cfh;
        print "Generated schema at $cfile\n";
    }
}
exit;

