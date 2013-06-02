#!/usr/bin/perl5.10
use strict;
use warnings;
use Carp qw(carp croak);
use Data::Dumper;

use KinoSearch::Searcher;
use KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::Search::SortSpec;

my $path = '/home/tina/develop/sf/battie/battie/searchindex';

use WWW::Battie::Search::Date;
use WWW::Battie::Search::Poard;
my $searcher = KinoSearch::Searcher->new(
    index => $path,
);

my $sort_spec = KinoSearch::Search::SortSpec->new(
    rules => [
#        KinoSearch::Search::SortRule->new( field => 'title' ),
        KinoSearch::Search::SortRule->new( field => 'date' ),
    ],
);
#$sort_spec->add(
#    field => 'date',
#    reverse => 1,
#);
#exit;
my $hits = $searcher->hits(
    query => "foo",
#    sort_spec => $sort_spec,
);
while ( my $hit = $hits->next ) {
    my $score = $hit->get_score;
    my $date = $hit->{date};
    my $id = $hit->{id};
    my $tid = $hit->{thread_id};
    my $bid = $hit->{board_id};
    print "$score: $hit->{title} #$id ($date) ($tid, $bid)\n";
}
