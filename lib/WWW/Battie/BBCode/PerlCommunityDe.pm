package WWW::Battie::BBCode::PerlCommunityDe;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use HTML::Entities;
use URI::Escape qw/ uri_escape uri_escape_utf8 /;
use File::Temp qw/ tempfile /;

sub html_tags {
    my ($class, $battie) = @_;
    my $self_url = $battie->self_url;
    my $bbcode_images = $battie->get_paths->{bbcode};
    my %tags = (
        perlmonks => {
            class => 'url',
            output => qq{<a href="http://www.perlmonks.org/?node=%{uri}A" rel="nofollow" class="icon_link"><img src="$bbcode_images/pm.gif" alt="Perlmonks:">%s</a>},
            example => {
                source => 'link to [perlmonks]123[/perlmonks] node and [perlmonks=124]another node[/perlmonks] and [perlmonks://125|yet another node]',
            },
            short => 1,
        },
        dist => {
            class => 'url',
            output => qq{<a href="http://search.cpan.org/dist/%{uri}A" class="icon_link"><img src="$bbcode_images/cpan.gif" alt="CPAN:">%s</a>},
            example => {
                source => '[dist]Parse-BBCode[/dist] [dist=Parse-BBCode]cpan dist[/dist] [dist://Parse-BBCode]',
                description => 'Link zu einer Distribution auf search.cpan.org. Fuer den Link zum direkten Modul [mod] verwenden.',
            },
            short => 1,
        },
        cpan => {
            class => 'url',
            output => qq{<a href="https://metacpan.org/search?q=%{uri}A" class="icon_link"><img src="$bbcode_images/cpan.gif" alt="CPAN:">%s</a>},
            example => {
                source => '[cpan]Parse::BBCode[/cpan] [cpan=Parse::BBCode]cpan search[/cpan] [cpan://Parse::BBCode]',
                description => 'Suche auf metacpan.org. Fuer den Link zum direkten Modul [mod] verwenden.',
            },
            short => 1,
        },
        pod => {
            class => 'url',
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback) = @_;
                my $title;
                my $url = '';
                if ($attribute_fallback =~ m/^(\w+(?:::\w+)*)(?:#(\S+))?\z/) {
                    my $mod = $1;
                    if (not defined $attr or not length $$content) {
                        $title = $1;
                    }
                    my $anchor = $2;
                    $mod =~ s#::#/#g;
                    $url = "$mod.html";
                    if ($anchor) {
                        $url .= '#' . uri_escape_utf8($anchor);
                        if (not defined $attr or not length $$content) {
                            $title .= " $anchor";
                        }
                    }
                }
                elsif ($attribute_fallback =~ m/^perlfunc\.([^#]+)\z/) {
                    my $func = $1;
                    $url = "functions/" . uri_escape_utf8($func) . ".html";
                    if (not defined $attr or not length $$content) {
                        $title = "perlfunc $func";
                    }
                }
                if (defined $title) {
                    $title = Parse::BBCode::escape_html($title);
                }
                else {
                    $title = $$content;
                }
                return qq{<a href="http://perldoc.perl.org/$url" class="icon_link"><img src="$bbcode_images/perldoc.gif" alt="Perldoc:">$title</a>};
            },
            example => {
                source => '[pod]perlmodinstall[/pod] [pod://perlintro] [pod]File::Find#%options[/pod] link to builtin: [pod]perlfunc.chomp[/pod]',
            },
            short => 1,
        },
        mod => {
            class => 'url',
            output => qq{<a href="https://metacpan.org/module/%{uri}A" class="icon_link"><img src="$bbcode_images/cpan.gif" alt="CPAN:">%s</a>},
            example => {
                source => '[mod]Parse::BBCode[/mod] [mod://Parse::BBCode]',
            },
            short => 1,
        },
        wp => {
            class => 'url',
            output => qq{<a href="http://de.wikipedia.org/wiki/%{uri}A" class="icon_link"><img src="$bbcode_images/wp.png" alt="Wikipedia:">%s</a>},
            example => {
                source => '[wp]Larry_Wall[/wp] [wp=Larry_Wall]wikipedia link[/wp]',
            },
        },
        wiki => {
            class => 'url',
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback) = @_;
                my ($web, $topic) = split m{[./]}, $attribute_fallback;
                for ($attr, $web) {
                    $_ = uri_escape_utf8 $_;
                }
                my $title = $attr ? $$content : $topic;
                return qq{<a href="http://wiki.perl-community.de/$web/$topic" class="icon_link"><img src="$bbcode_images/wiki.gif" alt="Wiki:">$title</a>};
            },
            example => {
                source => '[wiki]Wissensbasis/PerlFaq[/wiki] [wiki=Wissensbasis/PerlFaq]FAQ[/wiki]',
                description => 'Den "WikiNamen" kann man aus der "echten" URL des Wiki-Artikels rauskopieren, also z.B. Wissensbasis/PerlFaq',
#                    result => qq{<a href="http://wiki.perl-community.de/Wissensbasis/PerlFaq" class="icon_link"><img src="$bbcode_images/wiki.gif" alt="Wiki:">PerlFaq</a> <a href="http://wiki.perl-community.de/Wissensbasis/PerlFaq" class="icon_link"><img src="$bbcode_images/wiki.gif" alt="Wiki:">FAQ</a>},
            },
        },
        perldoc => {
            class => 'url',
            output => qq{<a href="http://wiki.perl-community.de/Perldoc/%{uri}A">%s</a>},
            example => {
                source => '[perldoc]perlintro[/perldoc] [perldoc=perlintro]Deutsche perlintro[/perldoc]',
                description => 'Link zur deutschen Perldoc in unserem Wiki. Fuer Links auf perldoc.perl.org [pod] verwenden.',
            },
        },
        wpe => {
            class => 'url',
            output => qq{<a href="http://en.wikipedia.org/wiki/%{uri}A" class="icon_link"><img src="$bbcode_images/wp.png" alt="Wikipedia:">%s</a>},
            example => {
                source => '[wpe]Larry_Wall[/wpe] [wpe=Larry_Wall]english wikipedia Larry Wall[/wpe]',
            },
        },
        code => {
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback, $token) = @_;
                code_render($parser, $attr, $content, $attribute_fallback, $token, $battie);
            },
            parse => 0,
            example => {
                source => qq{[code]some;csv;data\nand;some;more\n[/code]},
            },
        },
        perl => {
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback, $token) = @_;
                code_render($parser, 'perl', $content, $attribute_fallback, $token, $battie);
            },
            parse => 0,
            example => {
                    source => qq{[perl]package Foo;\n# automatically turns on strict and warnings:\nuse Moose;\nhas 'x' => (is => 'rw', isa => 'Int');\nhas 'y' => (is => 'rw', isa => 'Int');[/perl]},
            },
        },

    );
    return %tags;
}

sub text_tags {
    my ($class, $battie) = @_;
    my $self_url = $battie->self_url;
    my %tags = (
        code   => {
            code => sub {
                my $c = $_[2];
                "----- Code: -----\n$$c\n-----------------"
            },
        },
        perlmonks      => {
            code => sub {
               (defined $_[1] and length $_[1])
                ? qq{"$_[2]":http://www.perlmonks.org/?node=$_[1]}
                : qq{http://www.perlmonks.org/?node=$_[2]}
            },
        },
        wp => {
            parse => 1,
            code => sub {
                my ($path, $title) = @_[1,2];
                if (not defined $path or not length $path) {
                    $path = $title;
                }
                qq{$title:http://de.wikipedia.org/wiki/$path}
            },
        },
        wpe => {
            parse => 1,
            code => sub {
                my ($path, $title) = @_[1,2];
                no warnings 'uninitialized';
                unless (length $path) {
                    $path = $title;
                }
                qq{$title:http://en.wikipedia.org/wiki/$path}
            },
        },
        wiki => {
            parse => 1,
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback) = @_;
                my ($web, $topic) = split m{[./]}, $attribute_fallback;
                my $title = $attr ? $attr : $$content;
                $title = Parse::BBCode::escape_html($title);
                for ($attr, $web) {
                    $_ = uri_escape_utf8 $_;
                }
                return qq{$title:http://wiki.perl-community.de/$web/$topic};
            },
        },
        cpan => {
            output => qq{%s:https://metacpan.org/search?q=%{uri}A&mode=all},
        },
        mod => {
            class => 'url',
            output => qq{%s:https://metacpan.org/module/%{uri}A},
            short => 1,
        },
        pod => {
            class => 'url',
            output => qq{%s:http://perldoc.perl.org/%{uri}A.html},
            short => 1,
        },
        dist => {
            output => qq{%s:http://search.cpan.org/dist/%{uri}A"},
        },
    );
    return %tags;
}

sub code_render {
    my ($parser, $attr, $content, $attribute_fallback, $token, $battie) = @_;
    my $params = $parser->get_params;
    $params->{tag_info}->{code}++;
    my $self_url = $battie->self_url;
    my $counter = $token->get_num;
    my $at = $token->get_attr;
    my $tabs = 8;
    for my $item (@$at) {
        my ($name, $val) = @$item;
        next unless defined $name;
        if ($name eq 'tabs') {
            if (defined $val and $val =~ m/^(1|2|3|4|6|8|16)\Z/) {
                $tabs = $1;
            }
        }
    }
    my $code = $$content;
    my $lang;
    my @langs = qw/
        C H bison c caml cc changelog cpp cs csharp diff eps
        flex fortran h hh hpp htm html java javascript js l lang langdef
        latex lex lgt ll log logtalk lua ml mli outlang pas
        pascal patch perl php php3 pl pm postscript prolog ps
        py python rb ruby sh shell sig sml style syslog tex
        xhtml xml y yacc yy
    /;
    my $re = join '|', @langs;
    if ($attr and $attr =~ m/^($re)\z/) {
        $lang = $1;
    }
    $$content =~ s/^(?:\r?\n|^\r)+//;
    $$content =~ s/(?:\r?\n|^\r)+\z//;
    my $lines = $$content =~ tr/\n// + 1;
    my $numbers = join '<br>', 1 .. $lines;
    my $highlighted = '';
    my $big = $$content =~ m/[^\n]{100,}/ ? 1 : 0;
    my $success = 0;


    if ($lang) {
        my ($fh, $filename) = tempfile();
        binmode $fh, ':encoding(utf8)';
        print $fh $$content;
        close $fh;
        open my $pipe, "-|", '/usr/bin/source-highlight',
            '-s', $lang, '-css', '--no-doc',
            ($tabs ? ('--tab', $tabs) : ()),
        '--input', $filename or die "could not open: $!";
        binmode $pipe, ':encoding(utf8)';
        while (<$pipe>) {
            #warn __PACKAGE__.':'.__LINE__.": line $_\n";
            $highlighted .= $_;
        }
        #warn __PACKAGE__.':'.__LINE__.": SUCCESS\n";
        $success = 1;
        unlink $filename;

    }
    unless ($success) {
        $highlighted = encode_entities($$content);
        $highlighted =~ s/\r?\n|\r/<br>/g;
        $highlighted = "<pre><tt>$highlighted</tt></pre>";
    }
    else {
        $numbers = join '', map {
            qq{<span class="linenum">$_</span>\n}
        } 1 .. $lines;
    }
    my $headline = $lang ? "Code ($lang):" : "Code:";
    my $dl = '';
    if (defined $params->{poard}->{msid}) {
        my $msid = $params->{poard}->{msid};
#        my $more = $more_id ? "?more_id=$more_id" : '';
        $dl = <<EOM;
<a href="$self_url/poard/message/$msid/code/code_${msid}_$counter.txt">dl</a>
EOM
    }
    $numbers = $lines > 1
        ? qq{<div class="codelines"><pre><tt>$numbers</tt></pre></div>}
        : '<div style="clear: both;"></div>';
    return <<"EOM";
<div class="code_container">
<div class="codeheader" style="">$headline ($dl)</div>
$numbers
<div class="codebox" style="">$highlighted</div>
<div style="clear: both;"></div>
</div>
EOM

    return $big ? <<"EOM" : <<"EOM";
<div class="codebox"><table class="code"><tr><th colspan="2">$headline ($dl)</th></tr>
<tr>
$numbers
<td valign="top">
<div class="code">$highlighted</div>
</td>
</tr></table></div>
EOM
<div class="codebox"><table class="code"><tr><th colspan="2">$headline ($dl)</th></tr>
<tr>
$numbers
<td valign="top">
<div class="code">$highlighted</div>
</td>
</tr></table></div>
EOM

}

1;
