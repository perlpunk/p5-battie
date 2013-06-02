package WWW::Battie::Module;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw(seo));
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(seo));

sub register {
    my ($class) = shift;
    WWW::Battie::register($class, @_);
}

sub exception {
    WWW::Battie::exception(@_);
}

sub super_from_ini {
    my ($class, @args) = @_;
    my $self = $class->from_ini(@args);
    my $battie = shift @args;
    my $args = shift @args;

    # set options for search engines
    my $seo_index = $args->{SEO_INDEX} || 'no';
    my $seo_archive = $args->{SEO_ARCHIVE} || 'no';
    $seo_index = {map {
        ( $_ => 1 )
    } split m/\s*,\s*/, $seo_index} if $seo_index =~ tr/,//;
    $seo_archive = { map {
        ( $_ => 1 )
    } split m/\s*,\s*/, $seo_archive} if $seo_archive =~ tr/,//;
    for ($seo_index, $seo_archive) {
        next if ref $_;
        $_ = ($_ eq 'yes' ? 1 : 0);
    }
    $self->set_seo({
        index   => $seo_index,
        archive => $seo_archive,
    });
    return $self;
}

sub from_ini {
    my ($class) = @_;
    my $self = $class->new;
    return $self;
}

sub title {
    my ($self) = @_;
    return (split /::/, ref $self)[-1];
}

sub make_subtitle {
    my ($self, $page, %map) = @_;
    my $format = $self->get_html_titles->{$page};
    my @replace;
    $format =~ s/%(\w+)/push @replace, "$1"; '%s'/eg;
    my $res = sprintf $format, map { $map{$_} } @replace;
    return $res;
}

1;
