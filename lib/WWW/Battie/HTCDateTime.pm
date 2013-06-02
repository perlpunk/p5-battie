package WWW::Battie::HTCDateTime;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use DateTime;
use POSIX;
use base 'Class::Accessor::Fast';
#__PACKAGE__->mk_ro_accessors(qw/ timezone lang /);
#__PACKAGE__->follow_best_practice;
#__PACKAGE__->mk_wo_accessors(qw/ timezone lang /);
HTML::Template::Compiled->register(__PACKAGE__);
my $TIMEZONE;
my $TRANSLATE;
my $NOW;
my $NOW_DT;
my %days;

sub init_request {
    my ($class, %args) = @_;
    if (my $t = $args{translate}) {
#    warn __PACKAGE__.':'.__LINE__.": init_request\n";
        $TRANSLATE = $t;
        %days = (
            today       => $t->translate("global_today"),
            yesterday   => $t->translate("global_yesterday"),
        );
    }
    if (my $t = $args{timezone}) {
        $TIMEZONE = $t;
        $NOW = time;
#        $NOW_DT = DateTime->now( time_zone => $TIMEZONE );
    }
}

sub register {
    my ($class) = @_;
    my %plugs = (
        escape => {
            TIME => sub { timestr('full', @_) },
            TIME_YMD_HMS => sub { timestr('ymd_hms', @_) },
            TIME_YMD => sub { timestr('ymd', @_) },
            TIME_HTML => sub { timestr('html', @_) },
            TIME_HTML_FULL => sub { timestr('full_html', @_) },
            TIME_HTML_SHORT => sub { timestr('short_html', @_) },
            TIME_ONLY => sub { timestr('time_only', @_) },
        },
    );
    return \%plugs;
}

sub timestr {
    my ($type, $var) = @_;
    defined $var or return '';
    if (1) {
        my $now = time;
        my $epoch = $var;
        if (ref $var) {
            $epoch = $var->epoch;
        }
        my $diff = $now - $epoch;
        my $diff_minutes = int($diff / 60);
        my $diff_hours = int($diff_minutes / 60);
        local $ENV{TZ} = $TIMEZONE;
        my @lt = localtime($epoch);
        my $long = POSIX::strftime("%G-%m-%d %H:%M:%S %z (%Z)", @lt);
        if ($type eq 'full_html') {
            return qq{<span class="datetime" title="$long">$long</span>};
        }
        elsif ($type eq 'html' or $type eq 'short_html') {
            if ($diff_minutes <= 59) {
                $diff_minutes ||= 1;
                my $short = $TRANSLATE->translate("global_x_minutes_ago", $diff_minutes, [$diff_minutes]);
                return qq{<span class="datetime" title="$long">$short</span>};
            }
            elsif ($diff_hours <= 2) {
                # less than 2 hours ago
                my $short = $TRANSLATE->translate("global_x_hours_ago", $diff_hours, [$diff_hours]);
                return qq{<span class="datetime" title="$long">$short</span>};
            }
            elsif ($diff_hours <= 24 * 2) {
                my ($now_year, $now_dof) = (localtime $now)[5, 7];
                my ($var_year, $var_dof, $var_minute, $var_hour) = @lt[5, 7, 1, 2];
                my $short = POSIX::strftime("%G-%m-%d %H:%M", @lt);
                if ($now_year == $var_year) {
                    if ($var_dof == $now_dof) {
                        $short = sprintf "$days{today} %02d:%02d", $var_hour, $var_minute;
                    }
                    elsif ( (1+$var_dof) == $now_dof) {
                        $short = sprintf "$days{yesterday} %02d:%02d", $var_hour, $var_minute;
                    }
                    return qq{<span class="datetime" title="$long">$short</span>};
                }
            }

            my $short = POSIX::strftime("%G-%m-%d %H:%M", @lt);
            return qq{<span class="datetime" title="$long">$short</span>};
        }
        elsif ($type eq 'full') {
            return $long;
        }
        elsif ($type eq 'time_only') {
            my ($var_second, $var_minute, $var_hour) = @lt[0, 1, 2];
            my $short = sprintf "%02d:%02d:%02d", $var_hour, $var_minute, $var_second;
            return $short;
        }
        elsif ($type eq 'ymd_hms') {
            my $short = POSIX::strftime("%G-%m-%d %H:%M:%S", @lt);
            return $short;
        }
        elsif ($type eq 'ymd') {
            my $short = POSIX::strftime("%G-%m-%d", @lt);
            return $short;
        }
    }
    $var = $var->clone->set_time_zone('UTC'); # first let DateTime know the current zone
    $var->set_time_zone($TIMEZONE);
    my $offset = $var->offset;
    my $min = $offset % 3600;
    my $hour = int($offset / 3600);
    my $sign = $offset < 0 ? "-" : "+";
    my $long = sprintf "%s %s%02d:%02d", "$var", $sign, $hour, $min;
    $long =~ tr/T/ /;
    if ($type eq 'full') {
        return $long;
    }
    elsif ($type eq 'full_html') {
        return qq{<span class="datetime" title="$long">$long</span>};
    }
    elsif ($type eq 'time_only') {
        my $short = sprintf "%02d:%02d:%02d", $var->hour, $var->minute, $var->second;
        return $short;
    }
    elsif ($type eq 'ymd_hms') {
        my $short = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $var->year, $var->month, $var->day, $var->hour, $var->minute, $var->second;
        return $short;
    }
    elsif ($type eq 'html' or $type eq 'short_html') {

        my $short = sprintf "%04d-%02d-%02d %02d:%02d", $var->year, $var->month, $var->day, $var->hour, $var->minute;
        my $time = time;
        my $diff_minutes = int(($time - $var->epoch) / 60);
        my $diff_hours = int($diff_minutes / 60);
        if ($diff_minutes < 60) {
            # less than 60 minutes ago
            $diff_minutes ||= 1;
            my $short = $TRANSLATE->translate("global_x_minutes_ago", $diff_minutes, [$diff_minutes]);
            return qq{<span class="datetime" title="$long">$short</span>};
        }
        elsif ($diff_hours <= 2) {
            # less than 6 hours ago
            my $short = $TRANSLATE->translate("global_x_hours_ago", $diff_hours, [$diff_hours]);
            return qq{<span class="datetime" title="$long">$short</span>};
        }
        elsif ($diff_hours <= 24 * 2) {
            # less than 2 days ago
            #my $now = DateTime->now->set_time_zone($TIMEZONE);
            my $now_dof = $NOW_DT->day_of_year;
            my $var_dof = $var->day_of_year;
            my $now_year = $NOW_DT->year;
            my $var_year = $var->year;
            #warn __PACKAGE__.':'.__LINE__.": ($now) ($var) $now_year $var_year $now_dof $var_dof\n";
            if ($now_year == $var_year) {
                if ($var_dof == $now_dof) {
                    $short = sprintf "$days{today} %02d:%02d", $var->hour, $var->minute;
                }
                elsif ( (1+$var_dof) == $now_dof) {
                    $short = sprintf "$days{yesterday} %02d:%02d", $var->hour, $var->minute;
                }
                return qq{<span class="datetime" title="$long">$short</span>};
            }
        }
        return qq{<span class="datetime" title="$long">$short</span>};
    }

}

sub serialize {
    my ($self) = @_;
    my $clone = $self->clone;
#    $clone->set_timezone(undef);
#    $clone->set_lang(undef);
    return $clone;
}


sub clone {
    my ($self) = @_;
    my $clone = bless {%$self}, ref $self;
    return $clone;
}


1;
