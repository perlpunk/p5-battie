#!/usr/bin/perl
use strict;
use warnings;
use Carp qw(carp croak);
use Data::Dumper;
use WWW::Battie;
use Text::CSV_XS;
my $inifile = shift or die "We need an ini file";
my @files = @ARGV;
unless (@files) {
    die "Usage: $0 inifile translation_file1.csv translation_file2.csv ...\n";
}
my $ini = WWW::Battie::Config::Ini->create($inifile);
my $battie = WWW::Battie->from_ini( $ini );
my $version = WWW::Battie->VERSION;
my $max_multiline = $ENV{MAX_MULTILINE} || 5;

my $csv = Text::CSV_XS->new({
    sep_char => ";",
    binary => 1,
});
my %idx = (
    lang => 0,
    id => 1,
    translation => 2,
    plural => 3,
);
use Devel::Peek;
my %to_delete;
for my $file (@files) {
    print "Processing file '$file'...\n";
    my @data;
    open my $fh, "<:utf8", $file or die "Could not open '$file': $!";
    my $line = '';
    while (my $iline = <$fh>) {
        chomp $iline;
        next unless length $iline;
        $line .= $iline;
        my $multiline = 1;
        #warn __PACKAGE__.':'.__LINE__.": line $iline\n";
        while (not(my $status = $csv->parse($line))) {
            #sleep 1;
            if (eof $fh) {
                # reached end, error
                die "END!!";
            }
            #warn "Error in line $. of '$file': '$line'\n";
            #Dump $line;
            my $bad_argument = $csv->error_input();
            #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$bad_argument], ['bad_argument']);
            my $iline = <$fh>;
            chomp $iline;
            $line .= $/ . $iline;
            $multiline++;
            if ($multiline > $max_multiline) {
                my $start_multi = 1 + $. - $multiline;
                warn "Found entry with more than $max_multiline lines, starting at $file line $start_multi.\nIf you want longer lines than that, run the script with 'MAX_MULTILINE=n' in front.\n";
                exit;
            }
        }
        $line = '';
        my @columns = $csv->fields();
        #warn __PACKAGE__.':'.__LINE__.": (@columns)\n";
        #sleep 3;
        if ($. == 1) {
            for my $i (0 .. $#columns) {
                my $name = $columns[$i];
                $idx{$name} = $i;
            }
            next;
        }
        my $lang = $columns[ $idx{lang} ];
        $to_delete{ $lang }++;
        @columns = (@columns[ $idx{lang}, $idx{id}, $idx{translation}, $idx{plural} ]);
        push @data, \@columns;
    }
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@data], ['data']);
    #next;
    $battie->module_call(system => 'add_translation_data', \@data,
        {
            overwrite => 1,
        }
    );
}
for my $lang (keys %to_delete) {
    warn __PACKAGE__.':'.__LINE__.": delete cache system/trans/$lang\n";
    $battie->delete_cache("system/trans2/$lang");
}
print "Done.\n";

__END__
