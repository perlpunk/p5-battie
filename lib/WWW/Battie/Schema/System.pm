package WWW::Battie::Schema::System;
our $VERSION = '0.01_004';
use base qw/DBIx::Class::Schema WWW::Battie::Schema/;
#__PACKAGE__->load_classes();
my $loaded = 0;
sub load_classes_once {
    unless ($loaded) {
        __PACKAGE__->load_classes();
        $loaded = 1;
    }
}

{
package WWW::Battie::Schema::System::Language::Readonly;
use base 'WWW::Battie::Accessor';
my @acc = qw( id name fallback active );
__PACKAGE__->follow_good_practice;
__PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Battie::Schema::System::Translation::Readonly;
use base 'WWW::Battie::Accessor';
my @acc = qw( id lang translation plural );
__PACKAGE__->follow_good_practice;
__PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Battie::Schema::System::Terms::Readonly;
use base 'WWW::Battie::Accessor';
my @acc = qw/ id name content start_date style active rendered /;
__PACKAGE__->follow_good_practice;
__PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Battie::Schema::System::TermUser::Readonly;
use base 'WWW::Battie::Accessor';
my @acc = qw/ term_id start_date user_id /;
__PACKAGE__->follow_good_practice;
__PACKAGE__->mk_accessors(@acc);
}


1;

