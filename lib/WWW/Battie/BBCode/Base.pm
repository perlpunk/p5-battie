package WWW::Battie::BBCode::Base;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use HTML::Entities;
use URI::Escape qw/ uri_escape uri_escape_utf8 /;

my %color_light = (
    aqua    => 1,
    black   => 0,
    blue    => 0,
    fuchsia => 0,
    gray    => 0,
    grey    => 0,
    green   => 0,
    lime    => 0,
    maroon  => 0,
    navy    => 0,
    olive   => 0,
    purple  => 0,
    red     => 0,
    silver  => 1,
    teal    => 0,
    white   => 1,
    yellow  => 1,
);
my $color_names_re = join '|', sort keys %color_light;


sub html_tags {
    my ($class, $battie) = @_;
    my $self_url = $battie->self_url;
    my %tags = (
        'b'     => {
            output => '<b>%s</b>',
            example => {
                source => 'some [b]bold[/b] text',
            },
        },
        'i'     => {
            output => '<i>%s</i>',
            example => {
                source => 'some [i]italic[/i] text',
            },
        },
        'u'     => {
            output => '<u>%s</u>',
            example => {
                source => 'some [u]underlined[/u] text',
            },
        },
        'size'  => {
            output => '<span style="font-size: %{num}apt">%s</span>',
            example => {
                source => '[size=16]bigger[/size] and [size=2]smaller[/size] text',
            },
        },
        'noparse' => {
            output => '%{html}s',
            example => {
                source => qq{[noparse]this text can be full\nof [b]bbcode tags and will\nnot be parsed[/noparse]},
            },
        },
        inv => {
            output => '',
        },
        hr => {
            class => 'block',
            output => '<hr>',
            single => 1,
            example => {
                source => qq{some text[hr]more text},
            },
        },
        'list'  => {
            parse => 1,
            class => 'block',
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback, $tag) = @_;
                $$content =~ s/^\n+//;
                $$content =~ s/\n+\z//;
                return "<ul>$$content</ul>";
            },
            example => {
                source => qq{[list][*]first\n[*]second\n[*]third\n[list][*]a\n[*]b[/list]\n[/list]},
            },
        },
        small  => {
            output => '<small>%s</small>',
            example => {
                source => '[small]small[/small] Text',
            },
        },
        tt     => {
            output => '<tt>%s</tt>',
            example => {
                source => '[tt]fixed width[/tt] text',
            },
        },
        strike => {
            output => '<strike>%s</strike>',
            example => {
                source => '[strike]text crossed out[/strike]',
            },
        },
        img => {
            output => '<a href="%A" rel="nofollow">%s</a>',
        },
        battie => {
            class => 'url',
            output => qq{<a href="$self_url/%{html}A">%s</a>},
            class => 'url',
        },
        color => {
            parse => 1,
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback) = @_;
                my $light = 0;
                my $color = lc $attribute_fallback;
                if (exists $color_light{$color}) {
                    $light = $color_light{$color};
                }
                elsif ($color =~ m/^#([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})\z/i) {
                    my ($R,$G,$B) = ($1,$2,$3);
                    $_ = hex $_ for ($R,$G,$B);
                    my $sum = $R+$G+$B;
                    $light = $sum > 380;
                }
                else {
                    return $$content;
                }
                my $bg = $light ? 'black' : 'white';
                return qq{<span style="color: $color; background-color: $bg">$$content</span>},
            },
            example => {
                source => '[color=blue]blue[/color] [color=#ffffff]white[/color]',
#                    result => qq{<span style="color: blue; background-color: white">blue</span> <span style="color: white; background-color: black">white</span>},
            },
        },
        c => {
            parse => 0,
            code => sub {
                my ($parser, $attr, $content) = @_;
                $$content = encode_entities($$content);
                $$content =~ s/ /&nbsp;/g;
                return qq{<span class="minicode">$$content</span>};
            },
            example => {
                source => 'Some [c]code example <hr>[/c] inline',
            },
        },
        'url'   => {
            output => 'url:<a href="%{link}A" rel="nofollow">%s</a>',
            example => {
                source => qq{link to [url=http://www.perl.org/]Perl 5[/url]\nand [url]http://perl6.org[/url]},
            },
        },
    );
    return %tags;
}

sub text_tags {
    my ($class, $battie) = @_;
    my $self_url = $battie->self_url;
    my %tags = (
        i      => '_%s_',
        b      => '*%s*',
        small  => { output => '%s' },
        tt     => { output => '%s' },
        strike => { output => '[durchgestrichen]%s[/durchgestrichen]' }
    );
    return %tags;
}


1;

__END__


