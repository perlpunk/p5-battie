package HTML::Template::Compiled::Plugin::Translate;
use strict;
use warnings;
use Carp qw(croak carp);
use HTML::Template::Compiled;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw/ map lang /);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_wo_accessors(qw/ map lang /);

our $VERSION = '0.01';
HTML::Template::Compiled->register(__PACKAGE__);
#use Devel::Peek;

sub register {
    my ($class) = @_;
    my %plugs = (
        tagnames => {
            HTML::Template::Compiled::Token::OPENING_TAG() => {
                TRANSLATE => [sub { exists $_[1]->{ID} }, qw(ID ARGS COUNT)],
            },
        },
        compile => {
            TRANSLATE => {
                open => \&make_translate,
            },
        },
    );
    return \%plugs;
}

sub clone {
    my ($self) = @_;
    my $clone = bless {%$self}, ref $self;
    return $clone;
}

sub serialize {
    my ($self) = @_;
    my $clone = $self->clone;
    $clone->set_map({});
    $clone->set_lang(undef);
    return $clone;
}

our $MAP = {
    'the search for %1:s found %2:d videos' => [
        'Suche nach %1:s hat %2:020d Video gefunden',
        'Suche nach %1:s hat %2:d Videos gefunden',
    ],
};
# [%translate name="the search for %1:s found %2:d videos" count=".items#" args=".search,.items#" %]

sub make_translate {
    my ($htc, $token, $args) = @_;
    my $OUT = $args->{out};
    my $attr = $token->get_attributes;
    my $id = $attr->{ID};
    my $count = $attr->{COUNT};
    if (not defined $count) {
        $count = 1;
    }
    elsif ($count =~ tr/0-9//c) {
        $count = $htc->get_compiler->parse_var($htc,
            var => $count,
            method_call => $htc->method_call,
            deref => $htc->deref,
            formatter_path => $htc->formatter_path,
        );
    }

    my $arg = $attr->{ARGS};
    my @arg = defined $arg ? split m/,/, $arg : ();
    for my $arg (@arg) {
        $arg = $htc->get_compiler->parse_var($htc,
            var => $arg,
            method_call => $htc->method_call,
            deref => $htc->deref,
            formatter_path => $htc->formatter_path,
        );
    }
    my $d_arg = join ",", @arg;
    my $d_id = Data::Dumper->Dump([\$id], ['id']);
    $d_id =~ s/^\$id = \\//;
    $d_id =~ s/;$//;
    my $expression = <<"EOM";
    $OUT HTML::Template::Compiled::Plugin::Translate::translate(\$t->get_plugin('HTML::Template::Compiled::Plugin::Translate'), $d_id, $count, \[$d_arg\]);
EOM
    return $expression;
}

sub translate {
    my ($self, $id, $count, $args) = @_;
    $args ||= [];
    my $map = $self->map;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$map], ['map']);
    #my $test = $map->{global_action_add};
    #Dump $test;
    my $entry = $map->{$id} or return $id;
    $count = 1 unless defined $count;
    my $translation = ($count == 1 or not defined $entry->[1])
        ? $entry->[0] : $entry->[1];
    if (@$args) {
        my @replace = $translation =~ m/(%(?:\d+:)?\w+)/g;
        $translation =~ s/(%)(\d+:)(\w+)/$1$3/g;
        my @args;
        for my $i (0..$#replace) {
            my $re = $replace[$i];
            my $pos = 0;
            if ($re =~ m/%(\d+):/) {
                $pos = $1 - 1;
            }
            push @args, $args->[$pos];
        }
        $translation = sprintf $translation, @args;
    }
    #Dump $translation;
    return $translation;
}

1;
