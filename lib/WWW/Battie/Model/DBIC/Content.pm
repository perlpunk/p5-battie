package WWW::Battie::Model::DBIC::Content;
our $VERSION = '0.01_003';
use base qw/DBIx::Class::Schema/;
#__PACKAGE__->load_classes();
my $loaded = 0;
sub load_classes_once {
    unless ($loaded) {
        __PACKAGE__->load_classes();
        $loaded = 1;
    }
}



sub valid_link {
    return if length $_[1] > 32;
    return $_[1] =~ tr/a-z0-9_//c ? 0 : 1;
}

sub valid_title {
    return length $_[1] > 64 ? 0 : 1;
}

sub reposition_childs {
    my ($class, $schema, $parent_id) = @_;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\@_], ['_']);
    warn __PACKAGE__." reposition_childs(@_)\n";
    my $page_rs = $schema->resultset('Page');
    my $all_pages = $page_rs->search(
        {
            parent => $position,
        },
        order_by => 'position',
    );
    my @pages;
    my $pos = 0;
    while (my $p = $all_pages->next) {
        if ($p->position > 0) {
            $pos++;
        }
        $p->position($pos);
        push @pages, $p;
    }
    for my $p (@pages) {
        $p->update;
        my $id = $p->id;
        my $pos = $p->position;
        warn __PACKAGE__." page $id $pos\n";
    }
}

{
package WWW::Battie::Model::DBIC::Content::MOTD::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw/ id weight content start end rendered /;
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_wo_accessors(@acc);
}
1;
