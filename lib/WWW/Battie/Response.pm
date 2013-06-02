package WWW::Battie::Response;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
use Date::Parse qw(str2time);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/
    cookie redirect header content_type status _last_modified expires
    no_cache no_archive no_index cgi_class cookie_path
    needs_navi secure keywords output encoding
/);


sub add_cookie {
    my ($self, $cookie) = @_;
    unless (ref $cookie =~ m/^CGI::.*Cookie/) {
        my $cookie_path = $self->get_cookie_path;
        $cookie = $self->new_cookie(-path => $cookie_path, %$cookie);
    }
    my $cookies = $self->get_cookie || [];
    push @$cookies, $cookie;
    $self->set_cookie($cookies);
    return $cookie;
}


my %status_codes = (
    'not modified' => 304,
);

sub set_status {
    my ($self, $status) = @_;

    unless ($status =~ /^\d/) {
    my $code = $status_codes{lc $status}
        or croak qq(No status code found for "$status");
    $status = "$code $status";
    }
    $self->set(status => $status);
}

sub set_last_modified {
    my ($self, $last_mod) = @_;

    unless ($last_mod =~ /^\d+\z/) {
        my $last_mod_parsed = str2time($last_mod);
        croak "unparseable date: $last_mod" unless defined $last_mod_parsed;
        return $self->set__last_modified($last_mod_parsed);
    }
    $self->set__last_modified($last_mod);
}

# Returns the Last-Modified header in HTTP format
sub get_last_modified {
    my ($self) = @_;
    return () unless defined $self->get__last_modified;
    return $self->get_cgi_class->{util}->can("expires")->($self->get__last_modified);
}

# Returns the Expires header in HTTP format
sub get_expires {
    my ($self) = @_;

    if (defined $self->get_last_modified) {
	# This is relevant for Opera.
	# Long expiration timeouts don't make sense if we want to take
	# advantage of If-Modified-Since.
	return $self->get_cgi_class->{util}->can("expires")->('now');
    }

    my $expires = $self->get('expires');
    return undef unless defined $expires;
    return $self->get_cgi_class->{util}->can("expires")->($expires);
}

my %defaults = (
    -secure => 0,
);
sub new_cookie {
    my ($self, %args) = @_;
    my $cookie = $self->get_cgi_class->{cookie}->new(
        -secure => ($self->get_secure ? 1 : 0),
        %args,
    );
    return $cookie;
}

1;
