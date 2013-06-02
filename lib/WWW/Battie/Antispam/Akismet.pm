package WWW::Battie::Antispam::Akismet;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use Moose;
use Net::Akismet;

has 'key' => (is => 'rw', isa => 'Maybe[Str]');
has 'url' => (is => 'rw', isa => 'Maybe[Str]');
has 'checker' => (is => 'rw', isa => 'Maybe[Object]');

sub connect {
    my ($self, %args) = @_;
    my $key = $self->key;
    my $url = $self->url;
    return $self->checker if $self->checker;
    my $akismet = Net::Akismet->new(
        KEY => $key,
        URL => $url,
    ) or do {
       warn "Could not create Net::Akismet";
       return;
    };
    $self->checker($akismet);
}

sub initialize {
    my ($class, %args) = @_;
    my $key = $args{KEY};
    my $url = $args{URL};
    my $self = $class->new({
            key => $key,
            url => $url,
        });
    $self->connect;
    return $self;
}

sub check {
    my ($self, %args) = @_;
    my $text = $args{text};
    my $ua = $args{useragent};
    my $ip = $args{ip};
    my $author = $args{author};
    my $email = $args{email};
    my $type = $args{type};

    my $akismet = $self->checker;
    unless ($akismet) {
        return 0;
    }
    my %fields = (
        USER_IP                 => $ip,
        COMMENT_USER_AGENT      => $ua,
#        COMMENT_USER_AGENT      => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en; rv:1.9.0.7) Gecko/2009021910 Firefox/3.0.7',
#        USER_IP                 => '60.217.248.150',
    );
    if ($text) {
        $fields{COMMENT_CONTENT} = $text;
    }
    if ($author) {
        $fields{COMMENT_AUTHOR} = $author;
    }
    if ($email) {
        $fields{COMMENT_AUTHOR_EMAIL} = $email;
    }
    if ($type) {
        $fields{COMMENT_TYPE} = $type;
    }
    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%fields], ['fields']);
    my $verdict = $akismet->check(
        %fields,
    );
    return $verdict eq 'true' ? 1 : 0;
}

1;
