package WWW::Battie::Model::DBIC::Gallery;
our $VERSION = '0.01_002';
use base qw/DBIx::Class::Schema WWW::Battie::Schema/;
__PACKAGE__->load_classes();

my $loaded = 0;
sub load_classes_once {
    unless ($loaded) {
        __PACKAGE__->load_classes();
        $loaded = 1;
    }
}


sub valid_title {
    my ($class, $title) = @_;
    return $title =~ m{^[\w :/()\[\]=.&"',.+!?*-]+\Z};
}
{
package WWW::Battie::Model::DBIC::Gallery::Image::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(id info title suffix position ctime mtime
newline);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_wo_accessors(qw(newline));
}

{
package WWW::Battie::Model::DBIC::Gallery::Info::Readonly;
use base 'WWW::Battie::Accessor';
my @acc = qw/ id title created_by image_count ctime mtime cat_id category cat /;
__PACKAGE__->follow_good_practice;
__PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Battie::Model::DBIC::Gallery::Category::Readonly;
use base 'WWW::Battie::Accessor';
my @acc = qw/ id title parent_id left_id right_id mtime parent left right
    level count total_count /;
__PACKAGE__->follow_good_practice;
__PACKAGE__->mk_accessors(@acc);

sub is_node {
    $_[0]->left_id + 1 == $_[0]->right_id
}

}

1;
