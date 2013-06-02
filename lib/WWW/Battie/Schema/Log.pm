package WWW::Battie::Schema::Log;
our $VERSION = '0.01_002';
use base qw/DBIx::Class::Schema WWW::Battie::Schema/;
#__PACKAGE__->load_classes();
my $loaded = 0;
sub load_classes_once {
    unless ($loaded) {
        __PACKAGE__->load_classes();
        $loaded = 1;
    }
}

package WWW::Battie::Schema::Log::LogEntry::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw/id user_id module action object_id object_type ip forwarded_for ctime comment referrer user country city /;
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);

sub object_type_short {
    my $type = $_[0]->object_type;
    (split m/::/, $type)[$type =~ m/Readonly/ ? -2 : -1]
}

1;
