package WWW::Battie::Render;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/ bbc2html bbc2text htmltags texttags /);
use HTML::Entities;
use URI::Escape qw/ uri_escape uri_escape_utf8 /;
use WWW::Battie::BBCode::Base;
use WWW::Battie::BBCode::PerlCommunityDe;
use Parse::BBCode;
use Parse::BBCode::Markdown;
use IPC::Open3 qw/ open3 /;
#use POSIX ();
use File::Temp qw/ tempfile /;
use URI::Find;

sub render_userref {
    my ($self, $battie, $u) = @_;
    if ($u !~ tr/0-9//c) {
        my $user_nick = $battie->module_call(login => 'get_user_nick_by_id', $u);
        $u = $user_nick;
    }
    encode_entities($u);
    return "<cite class=user>$u</cite>";
}

sub init {
    my ($class, $battie) = @_;
    my $schema;
    my $self_url = $battie->self_url;
    my $self = $class->new({
            bbc2html => undef,
            bbc2text => undef,
        });
    my $redir = $battie->get_paths->{redir};
    my $max_url = 50;
    my $finder = URI::Find->new(sub {
        my ($url) = @_;
        my $title = $url;
        if (length($title) > $max_url) {
            $title = substr($title, 0, $max_url) . "...";
        }
        my $escaped = Parse::BBCode::escape_html($url);
        my $escaped_title = Parse::BBCode::escape_html($title);
        my $href = qq{<a href="$escaped" rel="nofollow">$escaped_title</a>};
        return $href;
    });
    my $make_link = sub {
        my ($type, $id, $title, $params) = @_;
        $id =~ tr/0-9//cd;
        $title = '' unless defined $title;
        my $link;
        my $get_title;
        if (length $title and $id eq $title) {
            $title = '';
        }
        if ($type eq 'board') {
            unless (length $title) {
                my $board_title = $battie->module_call(poard => 'get_board_title_by_id', $id);
                $get_title = $board_title if defined $board_title;
            }
            $link = "$self_url/poard/board/$id";
        }
        elsif ($type eq 'thread') {
            unless (length $title) {
                my $thread_title = $battie->module_call(poard => 'get_thread_title_by_id', $id);
                $get_title = $thread_title;
            }
            $link = "$self_url/poard/thread/$id";
        }
        elsif ($type eq 'msg') {
            $get_title = "msg #$id";
            $link = "$self_url/poard/message/$id";
        }
        elsif ($type eq 'user') {
            unless (length $title) {
                my $user_nick = $battie->module_call(login => 'get_user_nick_by_id', $id);
                $get_title = $user_nick;
            }
            $link = "$self_url/member/profile/$id";
        }
        if (not length $title) {
            if (defined $get_title) {
                $title = $get_title;
            }
            else {
                $title = "$type $id";
            }
            $params->{titles}->{$type}->{$id} = $title;
            $title = Parse::BBCode::escape_html($title);
        }
#        $title = Parse::BBCode::escape_html($title);
        $link = Parse::BBCode::escape_html($link);
        my $url = qq{<a href="$link">$title</a>};
        return $url;
    };

    my $escape = sub { Parse::BBCode::escape_html($_[0]) };
    my %base = WWW::Battie::BBCode::Base->html_tags($battie);
    my %perl_community_de = WWW::Battie::BBCode::PerlCommunityDe->html_tags($battie);
    my $htmltags = {
            Parse::BBCode::HTML->defaults,

#            '' => sub {
#                my ($parser, $attr, $content, $info) = @_;
#                if ($info->{classes}->{url}) {
#                    # only find urls when not alread in url like tag
#                    $finder->find(\$content, $escape);
#                }
#                else {
#                    $content = Parse::BBCode::escape_html($content);
#                }
#                $content =~ s{\[(thread|msg|board|user)://(\d+)(?:\|([^\]]+))?\]}
#                {$make_link->($1,$2,$3)}ge;
#                $content =~ s/\r?\n|\r/<br>\n/g;
#                $content
#            },
            %base,
            %perl_community_de,

            board => {
                short => 1,
                class => 'url',
                code => sub {
                    my ($parser, $attr, $content, $attribute_fallback) = @_;
                    my $params = $parser->get_params;
                    my $id = $attribute_fallback;
                    if ($id =~ tr/0-9//c) {
                        return '[board]' . encode_entities($id) . '[/board]';
                    }
                    $attribute_fallback = uri_escape_utf8 $attribute_fallback;
                    my $name;
                    $name = $$content if $attr;
                    return $make_link->('board',$id,$name, $params);
                },
                example => {
                    source => '[board]10[/board], [board=10]link to board[/board] [board://10|title]',
                },
            },
            user   => {
                short => 1,
                class => 'url',
                code => sub {
                    my ($parser, $attr, $content, $attribute_fallback) = @_;
                    my $id = $attribute_fallback;
                    if ($id =~ tr/0-9//c) {
                        return '[user]' . encode_entities($id) . '[/user]';
                    }
                    my $name;
                    if ($attr) {
                        # already escaped
                        $name = $$content;
                    }
                    my $params = $parser->get_params;
                    return $make_link->('user',$id,$name, $params);
                },
                example => {
                    source => '[user]1[/user], [user=1]link to user[/user] [user://1|title]',
                },
            },
            thread => {
                class => 'url',
                short => 1,
                code => sub {
                    my ($parser, $attr, $content, $attribute_fallback) = @_;
                    my $id = $attribute_fallback;
                    if ($id =~ tr/0-9//c) {
                        return '[thread]' . encode_entities($id) . '[/thread]';
                    }
                    my $name;
                    if ($attr) {
                        # already escaped
                        $name = $$content;
                    }
                    my $params = $parser->get_params;
                    return $make_link->('thread',$id,$name, $params);
                },
                example => {
                    source => '[thread]1[/thread], [thread=1]link to thread[/thread] [thread://1|title]',
#                    result => qq{<a href="$self_url/poard/thread/1">thread title</a>, <a href="$self_url/poard/thread/1">link to thread</a>},
                },
            },
            msg => {
                class => 'url',
                short => 1,
                code => sub {
                    my ($parser, $attr, $content, $attribute_fallback) = @_;
                    my $id = $attribute_fallback;
                    if ($id =~ tr/0-9//c) {
                        return '[msg]' . encode_entities($id) . '[/msg]';
                    }
                    # already escaped $$content
                    my $name;
                    $name = $$content if $attr;
                    my $params = $parser->get_params;
                    return $make_link->('msg',$id,$name, $params);
                },
                example => {
                    source => '[msg]1[/msg], [msg=1]link to message[/msg] [msg://1]',
#                    result => qq{<a href="$self_url/poard/message/1">msg 1</a>, <a href="$self_url/poard/message/1">link to message</a>},
                },
            },
            more => {
                parse => 1,
                code => sub {
                    my ($parser, $attr, $content, $attribute_fallback, $tag) = @_;
                    my $params = $parser->get_params;
                    $params->{tag_info}->{more}++;
                    my $l = length $$content;
                    my $raw = $tag->raw_content;
                    my $preview = substr($raw, 0, 200);
                    if (length($raw) > 200) {
                        $preview .= "...";
                    }
                    encode_entities($preview);
                    $l = $l > 1024 ? (sprintf "%.1fkb", $l/1024) : "${l}b";
                    my $counter = $tag->get_num;
                    my $msid = $params->{poard}->{msid};
                    my $title = "more";
                    if (defined $attr and length $attr) {
                        $title = $attr;
                        encode_entities($title);
                    }
#                    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$more_id], ['more_id']);
                    if (defined $msid and $params->{poard}->{more}) {
                        # collapsed view in thread
                        return <<EOM;
<a href="$self_url/poard/message/$msid#more_${msid}_$counter" title="show more ($preview)">$title ($l)</a><script type="text/javascript"><!--
write_loadmore($msid,$counter);
--></script>
EOM
                    }
                    else {
                        # full view in single message or message preview
                        # $msid is undef when in message preview
                        my $id = defined $msid ? $msid : 0;
                        my $header = <<"EOM";
<div id="more_header_${id}_$counter"><a name="more_${id}_$counter">$title ($l)</a>:
<script type="text/javascript"><!--
write_toggle('more_content_${id}_$counter');
--></script>
<br></div>
EOM
                        return <<EOM;
<div class="loadmore_header">$header
<div id="more_content_${id}_$counter">$$content</div>
</div>
EOM
                    }
                    return "";
                },
                example => {
                    source => '[more="Description"]very looooong text[/more]',
                    description => 'Will be collapsed and shown inline when clicking on the title',
                },
            },
            forumsearch => {
                class => 'url',
                code => sub {
                    my ($parser, $attr, $content, $attribute_fallback, $token) = @_;
                    my $term = $$content;
                    my $at = $token->get_attr;
                    my $rows = $at->[0]->[0];
                    $rows =~ tr/0-9//cd;
                    my $intitle = 0;
                    my $bydate = 0;
                    my @boards;
                    my $qs = "?";
                    for my $i (1 .. $#$at) {
                        my $item = $at->[$i];
                        my ($name, $val) = @$item;
                        if ($name eq 'intitle') {
                            $intitle = $val ? 1 : 0;
                            $qs .= "in_title=$intitle;";
                        }
                        elsif ($name eq 'bydate') {
                            $bydate = $val ? 1 : 0;
                            $qs .= "by_date=$bydate;";
                        }
                        elsif ($name eq 'boards') {
                            $val =~ tr/0-9//cd;
                            $val ||= 0;
                            @boards = $val;
                        }
                    }
                    my $sbid = $boards[0];
                    $qs .= "sbid=$sbid;" if $sbid;
                    $qs .= "rows=$rows;";
                    my $term_uri = uri_escape_utf8($term);
                    $qs .= "query=$term_uri";
                    return qq{<a href="$self_url/poard/search$qs" class="icon_link"><span class="magnifier">&nbsp;</span>$term</a>};
                },
                example => {
                    source => '[forumsearch=perl intitle=1 bydate=1]search[/forumsearch]',
                },
            },
            quote => {
                class => 'block',
                parse => 1,
                code => sub {
                    my ($parser, $attr, $content, $attribute_fallback, $tag) = @_;
                    my $who = $attr;
                    my $userquote = '';
                    my $is_user = 0;
                    if (defined $who and $who =~ s#\@([^@]+)\z##) {
                        my $date = encode_entities($1);
                        $userquote .= "<span class=date>$date</span>\n";
                        $is_user = 1;
                        my $userref = $battie->module_call(login => 'get_userref_by_nick', $who);
                        if ($userref) {
                            my $name = encode_entities($userref->[1]);
                            my $id = $userref->[0];
                            $userquote .= qq{<cite class=user><a href="$self_url/member/profile/$id">$name</a></cite>};
                        }
                    }
                    else {
                        if (defined $who) {
                            $userquote .= qq{<cite class=guest>$who</cite>};
                        }
                        else {
                            $userquote .= qq{<cite class=guest>Quote</cite>};
                        }
                    }
                    my $string = "<blockquote>$userquote<div>$$content</div></blockquote>";
                    return $string;
                },
                example => {
                    source => qq{[quote]some quoted text\nsome more quoted text[/quote]},
#                    result => qq{<blockquote><div>some quoted text<br>some more quoted text</div></blockquote>},
                },
            },
        };
    my $bbc2html = Parse::BBCode->new({
        url_finder => 1,
        linebreaks => 1,
#        text_processor => sub {
#            my ($text, $info) = @_;

#            if (!$info->{classes}->{url}) {
#                # only find urls when not alread in url like tag
#                $finder->find(\$text, $escape);
#            }
#            else {
#                $text = Parse::BBCode::escape_html($text);
#            }

#            $text =~ s{\[()://(\d+)(?:\|([^\]]+))?\]}
#            {$make_link->($1,$2,$3)}ge;
#            my $out = '';
#            while ($text =~ s{^(.*?)\[(thread|msg|board|user)://(\d+)(?:\|([^\]]+))?\]}{}s) {
#                my ($pre, $tagname, $num, $title) = ($1, $2, $3, $4);
#                $out .=
#                    Parse::BBCode::escape_html($pre)
#                    . $make_link->($tagname, $num, $title);
#            }
#            $out .= Parse::BBCode::escape_html($text);
#            return $text;
#        },
        tags => $htmltags,
    });
    $self->set_htmltags($htmltags);
    $self->set_bbc2html($bbc2html);
    my %base_text = WWW::Battie::BBCode::Base->text_tags($battie);
    my %perl_community_de_text = WWW::Battie::BBCode::PerlCommunityDe->text_tags($battie);
    my %text_def = (
        %base_text,
        %perl_community_de_text,
        img => {
            code => sub {
                qq{$_[2]},
            },
        },
        board  => {
            short => 1,
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback) = @_;
                my $id = $attribute_fallback;
                if ($id =~ tr/0-9//c) {
                    return '[board]' . encode_entities($id) . '[/board]';
                }

                my $name = '';
                $name = $$content if $attr;

                unless (length $name) {
                    my $board_title = $battie->module_call(poard => 'get_board_title_by_id', $id);
                    $name = $board_title;
                }
                qq{$self_url/poard/board/$id ("$name")}
            },
        },
        url => '"%s":%a',
        user   => {
            short => 1,
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback) = @_;
                my $id = $attribute_fallback;
                if ($id =~ tr/0-9//c) {
                    return '[user]' . encode_entities($id) . '[/user]';
                }
                my $name = '';
                if ($attr) {
                    # already escaped
                    $name = $$content;
                }
                unless (length $name) {
                    my $user_nick = $battie->module_call(login => 'get_user_nick_by_id', $id);
                    $name = $user_nick;
                }
                qq{$self_url/member/profile/$id ("$name")}
            },
        },
        thread => {
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback) = @_;
                my $id = $attribute_fallback;
                my $name = '';
                if ($attr) {
                    # already escaped
                    $name = $$content;
                }
                unless (length $name) {
                    my $thread_title = $battie->module_call(poard => 'get_thread_title_by_id', $id);
                    $name = $thread_title;
                    encode_entities($name);
                }
                qq{$self_url/poard/thread/$id ("$name")}
            },
            short => 1,
        },
        more => {
            parse => 1,
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback) = @_;
                my $params = $parser->get_params;
                my $l = length $$content;
                $l = $l > 1024 ? (sprintf "%.1fkb", $l/1024) : "${l}b";
                if (defined $params->{poard}->{msid}) {
                    my $msid = $params->{poard}->{msid};
                    return qq{more ($l): $self_url/poard/message/$msid};
                }
                else {
                    return qq{more ($l):$$content};
                }
            },
        },
        quote  => {
            parse => 1,
            code => sub {
                my ($parser, $attr, $content, $attribute_fallback) = @_;
                my $userref = '';
                my $arg = $_[1];
                if (defined $arg && length $arg) {
                    if ($arg =~ s#\@([^@]+)\z##) {
                        my $date = $1;
                        $userref .= "$date\n";
                    }
                    $userref .= $arg;
                }
                my $quote = $$content;
                $quote =~ s/^/> /gm;
                "Quote $userref:\n$quote"; # .
            },
        },
    );
    my $bbc2text2 = Parse::BBCode::Markdown->new({
        tags => {
            Parse::BBCode::Markdown->defaults,
            %text_def,
        },
    });
    $self->set_bbc2text($bbc2text2);
    return $self;
}

sub render_message_html {
    my ($self, $text, $msid, $more, $params) = @_;
    my $bbc = $self->get_bbc2html;
    # no inv tags
    my @forbid = qw/ inv /;
    $bbc->forbid(@forbid);
    $params ||= {};
    if ($msid) {
        $params->{poard}->{msid} = $msid;
    }
    if ($more) {
        $params->{poard}->{more} = 1;
    }
    my $parsed;
    if (ref($text) eq 'Parse::BBCode::Tag') {
        $parsed = $bbc->render_tree($text, $params);
    }
    else {
        $parsed = $bbc->render($text, $params);
    }
    $bbc->permit(@forbid);
    return $parsed;
}
sub parse_message {
    my ($self, $text, $msid) = @_;
    my $bbc = $self->get_bbc2html;
    # no inv tags
    my @forbid = qw/ inv /;
    $bbc->forbid(@forbid);
    my $params = {};
    if ($msid) {
        $params->{poard}->{msid} = $msid;
    }
    my $tree = $bbc->parse($text, $params);
    $bbc->permit(@forbid);
    return $tree;
}

sub find_tag {
    my ($self, $tag, $name, $i, $count) = @_;
    my $test = $tag->get_name;
    $name = [$name] unless ref $name;
    if (grep { $_ eq $test } @$name) {
        if ($$count >= $i) {
            # found
            return $tag;
        }
        $$count++;
    }
    my $content = $tag->get_content;
    my $found;
    for my $item (@$content) {
        if (ref $item) {
            $found = $self->find_tag($item, $name, $i, $count);
            return $found if $found;
        }
    }
}

sub find_text {
    my ($self, $parser, $tag, $sub) = @_;
    my $tags = $parser->get_tags;
    my $content = $tag->get_content;
    for my $item (@$content) {
        if (ref $item) {
            my $name = $item->get_name;
            my $def = $tags->{$name};
            if ($item->get_class ne 'url' and $def->{parse}) {
                $self->find_text($parser, $item, $sub);
            }
        }
        else {
            # text
            $sub->(\$item);
        }
    }
}

sub render_message_nodelet {
    my ($self, $text) = @_;
    my $bbc = $self->get_bbc2html;
    # no block tags in chatterbox
    my $parsed = $bbc->render($text);
    return $parsed;
}

sub render_message_chatterbox {
    my ($self, $text) = @_;
    my $bbc = $self->get_bbc2html;
    # no block tags in chatterbox
    my @forbid = qw/ code quote /;
    $bbc->forbid(@forbid);
    my $parsed = $bbc->render($text);
    $bbc->permit(@forbid);
    return $parsed;
}

sub render_message_text {
    my ($self, $text, $msid, $more) = @_;
    my $bbc2text = $self->get_bbc2text;
#    $bbc2text->set_tags(qw(
#            code b board i url user quote thread small
#            perlmonks img wp wpe cpan dist
#        ));
    my $params = {};
    if ($msid) {
        $params->{poard}->{msid} = $msid;
    }
    if ($more) {
        $params->{poard}->{more} = 1;
    }
    my $parsed = $bbc2text->render($text, $params);
#    $bbc2text->set_tags([]);
    return $parsed;
}

1;

__END__

=pod

=head1 NAME

WWW::Battie::Render

=cut

