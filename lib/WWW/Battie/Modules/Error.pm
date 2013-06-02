package WWW::Battie::Modules::Error;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module';
my %functions = (
    functions => {
        error => {
            message => 1,
            token   => 1,
            cookie  => 1,
        },
    },
);
__PACKAGE__->register(
    %functions
);
sub functions { %functions }

sub default_actions {
    my ($class, $battie) = @_;
    return {
        guest => [qw/ message token /],
    };
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        return {
            link => ['error', 'start'],
            text => 'error',
        };
    };
}


sub error__message {}

sub error__token {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    $request->get_cgi->delete('t');
    my $data = $battie->get_data;
    $data->{error}->{request} = $request;
    my $args = $request->get_args;
    $data->{error}->{action} = $request->get_page . '/' . $request->get_action . '/' . join('/', @$args);
    my $params = [];
    for my $key ($request->param) {
        my @val = $request->param($key);
        push @$params, [$key, $_] for @val;
    }
    $data->{error}->{params} = $params;
    my $submit = $request->get_submit;
    my $key = (keys %$submit)[0];
    $data->{error}->{submit} = "submit.$key";
}

sub error__cookie {
    shift->error__token(@_);
}

1;
