package WWW::Battie::BBCode;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use base 'Parse::BBCode';
#__PACKAGE__->mk_accessors(qw/ params /);

package WWW::Battie::BBCode::Markdown;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use base qw/ Parse::BBCode /;
__PACKAGE__->follow_best_practice;
#__PACKAGE__->mk_accessors(qw/ params /);

1;
