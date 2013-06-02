#!/usr/bin/perl5.10
use strict;
use warnings;
use Carp qw(carp croak);
use Data::Dumper;
use Fcntl qw/ :flock :seek /;

use KinoSearch::Indexer;
use KinoSearch::Analysis::PolyAnalyzer;
use WWW::Battie;
use WWW::Battie::Search::Poard;
use WWW::Battie::Search::Date;
my $ks_schema = KinoSearch::Schema->new;
my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
    language => 'de',
);
my $type = KinoSearch::FieldType::StringType->new(
#    analyzer => $polyanalyzer,
    indexed => 1,
    stored  => 1,
);
my $type_h = KinoSearch::FieldType::FullTextType->new(
    analyzer => $polyanalyzer,
    highlightable => 1,
);
for my $f (qw/ id thread_id board_id author_id author_name /) {
    $ks_schema->spec_field( name => $f, type => $type );
}
for my $f (qw/ title body /) {
    $ks_schema->spec_field( name => $f, type => $type_h );
}
#my $date_type = WWW::Battie::Search::Date->new(
my $date_type = KinoSearch::FieldType::StringType->new(
    sortable => 1,
    indexed => 1,
    stored  => 1,
);
$ks_schema->spec_field( name => 'date', type => $date_type );

my ($inifile, $rows, $rows_update, $what) = @ARGV;
$inifile or die "We need an ini file";
$rows ||= 1000;
$rows_update ||= 10;
$what ||= 'update'; # create or update
my $ini = WWW::Battie::Config::Ini->create($inifile);
$ini->{modules}->{'WWW::Battie::Modules::Poard'}->{SEARCH} = 'KinoSearch';
my $battie = WWW::Battie->from_ini( $ini );

#$ENV{DBIC_TRACE}=1;
my $m = $battie->get_modules;
my $name = 'poard';
my $module = $m->{$name};
#print "module $name @{[ ref $module ]}\n";
$battie->module_call($name => 'init_db');
my $schema = $battie->sub_call($name => 'schema')->{poard};
my $conf = $battie->sub_call($name => 'get_search');
#warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$conf], ['conf']);
my $path = $conf->{index};
unless (-d $path) {
    print "Directory '$path' does not exist, create first\n";
    exit;
}
my $lockfile = "$path/create_index.lock";
my $to_update = "$path/to_update.csv";


if ($what eq 'create') {
    create();
}
elsif ($what eq 'update') {
    update();
}

sub create {
    open my $lockfh, ">", $lockfile or die $!;
    flock $lockfh, LOCK_EX;
    print "Starting to recreate index...\n";
    {
        print "Truncating '$to_update'...\n";
        open my $fh, "+<", $to_update or die $!;
        flock $fh, LOCK_EX;
        truncate $fh, 0;
        close $fh;
    }
    my $found = 1;
    my $outer_loop = 0;
    my $count = 0;
    print "Searching articles...\n";
    while ($found) {
        $found = 0;
        my $create = $outer_loop ? 0 : 1;
        my $truncate = $outer_loop ? 0 : 1;
        my $indexer = KinoSearch::Indexer->new(
            index       => $path,
            create      => $create,
            schema      => $ks_schema,
            truncate    => $truncate,
        );
        $outer_loop++;
        my $search = $schema->resultset('Message')->search({
            'me.status' => 'active',
        },
        {
            prefetch    => { thread => 'board' },
            rows        => $rows,
            page        => $outer_loop,
        });
        while (my $msg = $search->next) {
            $found++;
            my $doc = $battie->module_call(poard => make_search_document => message => $msg);
            next unless $doc;
            $count++;
            #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$doc], ['doc']);
            $indexer->add_doc($doc);
            print "indexed $count articles\n" if $count % $rows == 0;
        }
        $indexer->commit;
    }
    print "indexed $count articles\n";
}

sub update {
    open my $lockfh, ">", $lockfile or die $!;
    unless (flock $lockfh, LOCK_EX | LOCK_NB) {
        print "Lockfile '$lockfile' locked, exiting\n";
        return;
    }
    print "Updating index with new articles...\n";
    my $indexer = KinoSearch::Indexer->new(
        index   => $path,
        create  => 0,
        schema  => $ks_schema,
    );
    open my $fh, "+<", $to_update or die $!;
    flock $fh, LOCK_EX;
    my @lines = <$fh>;
    my $count = 0;
    while (my $line = shift @lines) {
        $count++;
        chomp $line;
        eval {
            warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$line], ['line']);
            my ($action, $type, $id) = split m/;/, $line;
            if ($action eq 'update') {
                if ($type eq 'msg') {
                    my $msg = $schema->resultset('Message')->find($id);
                    next if (!$msg or $msg->status ne 'active');
                    my $doc = $battie->module_call(poard => make_search_document => message => $msg);
                    next unless $doc;
                    $indexer->delete_by_term( field => id => term => $id );
                    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$doc], ['doc']);
                    $indexer->add_doc($doc);
                }
                elsif ($type eq 'thread') {
                    my $thread = $schema->resultset('Thread')->find($id);
                    my $msgs = $thread->search_related('messages',
                        {
                            status => {'!=' => 'deleted'},
                        }
                    );
                    $indexer->delete_by_term( field => thread_id => term => $id );
                    while (my $msg = $msgs->next) {
                        my $doc = $battie->module_call(poard => make_search_document => message => $msg);
                        $indexer->add_doc($doc) if $doc;
                    }
                }
            }
            elsif ($action eq 'delete') {
                if ($type eq 'msg') {
                    $indexer->delete_by_term( field => id => term => $id );
                }
                elsif ($type eq 'thread') {
                    $indexer->delete_by_term( field => thread_id => term => $id );
                }
            }
        };
        last if $count > $rows_update;
        if ($@) {
            warn __PACKAGE__.':'.__LINE__.": !!! error: $@\n";
            unshift @lines, "$line$/";
            last;
        }
    }
    $indexer->commit;
    truncate $fh, 0;
    seek $fh, 0, SEEK_SET;
    print $fh @lines;
    close $fh;
    print "re-indexed/deleted $count articles/threads. done.\n";
}


