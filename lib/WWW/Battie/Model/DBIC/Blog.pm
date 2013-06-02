package WWW::Battie::Model::DBIC::Blog;
our $VERSION = '0.01';
use base qw/DBIx::Class::Schema/;
#__PACKAGE__->load_classes();
my $loaded = 0;
sub load_classes_once {
    unless ($loaded) {
        __PACKAGE__->load_classes();
        $loaded = 1;
    }
}


sub valid_title {
    my ($class, $title) = @_;
    return unless defined $title;
    return unless length $title;
    return length $title < 255;
}
{
    package WWW::Battie::Model::DBIC::Blog::Blog::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = qw(id title image created_by ctime mtime);
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);

    sub url_title {
        my $title = $_[0]->title;
        $title =~ tr/a-zA-Z0-9/_/c;
        return $title;
    }
}

{
package WWW::Battie::Model::DBIC::Blog::Theme::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(id title abstract image link message posted_by active is_news can_comment ctime mtime blog blog_id posted_by_user);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);
sub get_abstract_html {
    my ($self) = @_;
    my $textile = new Text::Textile;
    $textile->disable_html(1);
    my $html = $textile->process($self->get_abstract);
}
    sub cday {
        my ($day) = $_[0]->ctime =~ m/^\d{4}-\d{2}-(\d{2})/;
        return $day+0;
    }
}

1;
