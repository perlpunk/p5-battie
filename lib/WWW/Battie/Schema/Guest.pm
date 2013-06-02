package WWW::Battie::Schema::Guest;
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

{
package WWW::Battie::Schema::Guest::Entry::Readonly;
use base 'WWW::Battie::Accessor';
my @acc = qw/ id name email message url location ctime active comment comment_by approved_by mtime approver /;
__PACKAGE__->follow_good_practice;
__PACKAGE__->mk_accessors(@acc);

sub rendered_message {
    my $text = $_[0]->message;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&quot;/g;
    $text =~ s/(\r|\r\n|\r)+/<br>\n/g;
    return $text;
}
}

1;
