package WWW::Battie::Search::Poard;
use strict;
use warnings;

use base qw/ KinoSearch::Schema /;
use KinoSearch::Analysis::PolyAnalyzer;
use WWW::Battie::Search::Date;

our %fields = (
    id => 'text',
    title => 'text',
    body => 'text',
#    date => 'WWW::Battie::Search::Date',
    thread_id => 'text',
    board_id => 'text',
    author_id => 'text',
    author_name => 'text',
);

sub analyzer { 
    return KinoSearch::Analysis::PolyAnalyzer->new( language => 'de' );
}

1;
