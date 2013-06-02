#!/usr/bin/perl
use strict;
use warnings;
use URI::Escape qw(uri_unescape);
$ENV{QUERY_STRING} =~ s#^http%3A%2F%2F##i;
my $url = uri_unescape $ENV{QUERY_STRING};
$url =~ s{^http://}{};
$url =~ s/\s+//g;
my $url_html = $url;
$url_html =~ s/&/&amp;/g;
$url_html =~ s/</&lt;/g;
$url_html =~ s/>/&gt;/g;
$url_html =~ s/"/&quot;/g;

print <<"EOM";
Content-Type: text/html
Pragma: no-cache

<head>
<title>Redirect</title>
<meta name="robots" content="noindex,noarchive">
</head>
<body>
<p style="font-size: 16px; margin: 5em; padding: 1em; border: 2px dotted #333333;">
You requested a redirect to:
<br>
<a href="http://$url">http://$url_html</a>
</p>
</body>
EOM
