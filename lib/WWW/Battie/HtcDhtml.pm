package WWW::Battie::HtcDhtml;
# $Id: DHTML.pm,v 1.3 2006/11/20 19:02:33 tinita Exp $
use strict;
use warnings;
our $VERSION = "0.02";
use Data::TreeDumper;
use Data::TreeDumper::Renderer::DHTML;

HTML::Template::Compiled->register(__PACKAGE__);

sub register {
    my ($class) = @_;
    my %plugs = (
        escape => {
            DHTML => \&dumper,
        },
    );
    return \%plugs;
}

sub dumper {
	my ($var) = @_;
	my $style;
	my $body = DumpTree($var, 'Data',
		DISPLAY_ROOT_ADDRESS => 0,
		DISPLAY_PERL_ADDRESS => 0,
		DISPLAY_PERL_SIZE => 0,
		RENDERER => {
			NAME => 'DHTML',
			STYLE => \$style,
			BUTTON => {
				COLLAPSE_EXPAND => 1,
				SEARCH => 1,
			}
		}
	);
	return $style.$body;
}

1;

__END__

=pod

=head1 NAME

HTML::Template::Compiled::Plugin::DHTML - Dumps variables into clickable HTML output

=head1 SYNOPSIS

    use HTML::Template::Compiled::Plugin::DHTML;

    my $htc = HTML::Template::Compiled->new(
        plugin => [qw(HTML::Template::Compiled::Plugin::DHTML)],
        ...
    );

=head1 METHODS

=over 4

=item register

gets called by HTC

=item dumper

Dumps variables into clickable HTML. See L<examples/dhtml.html>.

=back

=cut

