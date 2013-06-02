package WWW::Battie::Modules::Cache;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module';
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(dir));
use Errno;
use Fcntl qw(:flock);
use File::Find qw(find);
my %functions = (
    functions => {
        cache => {
            start => 1,
            init => {
                on_run => 1,
            },
        },
    },
);
sub functions { %functions }
use Storable qw(store retrieve);
use File::Spec;
use File::Path;
use File::Basename;

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        return {
            link => ['cache', 'start'],
            text => 'Cache',
        };
    };
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$args], ['args']);
    my $dir = $args->{DIR};
    unless (File::Spec->file_name_is_absolute($dir)) {
        $dir = File::Spec->catfile($battie->get_paths->{serverroot}, $dir);
    }
    my $self = $class->new({
            dir => $dir,
        });
}

sub cache__init {}

sub delete_cache {
    my ($self, $battie, $key) = @_;
    return if $key =~ tr{a-zA-Z0-9_/:-}{}c;
    $key =~ s{ ^/ }{}x;
    split_numbers(\$key);
    my $dir = $self->get_dir;
    my $file = File::Spec->catfile($dir, "$key.storable");
    my $expire_file = File::Spec->catfile($dir, "$key.expire");
    if (-f $file) {
        open my $lock, '>', "$dir/lock" or die $!;
        flock $lock, LOCK_EX;
        unlink $file;
        unlink $expire_file;
        close $lock;
        return 1;
    }
    return;
}
sub split_numbers {
    # avoid more than 1000 entries in a directory
    my ($key) = @_;
    my @split = split m{/}, $$key;
    if ($split[-1] =~ m/^\d{4,}$/) {
        $split[-1] =~ s{(.{3})}{$1/}g;
    }
    $$key = join '/', @split;
}

sub from_cache {
    my ($self, $battie, @keys) = @_;
	my $hashref = {};
	for my $key (@keys) {
		next if $key =~ tr{a-zA-Z0-9_/:-}{}c;
		$key =~ s{ ^/ }{}x;
		split_numbers(\$key);
		my $dir = $self->get_dir;
		my $file = File::Spec->catfile($dir, "$key.storable");
		my $expire = File::Spec->catfile($dir, "$key.expire");
		#warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$file], ['file']);
		next unless -f $file;
		next unless -f $expire;
		open my $lock, '>', "$dir/lock" or die "Could not open '$dir/lock': $!";
		flock $lock, LOCK_SH;
		open my $fh, '<', $expire or next;
		chomp(my $expire_time = <$fh>);
		close $fh;
		#warn __PACKAGE__." reading from cache $file\n";
		if ($expire_time < time) {
			flock $lock, LOCK_EX;
			# is out of date, delete
			unlink $file;
			unlink $expire;
			close $lock;
			#warn __PACKAGE__." $file is outdated\n";
			next;
		}
		my $data = retrieve($file);
		my $mtime = (stat $file)[9];
		if (@keys > 1) {
			$hashref->{$key} = $data;
		}
		else {
			return wantarray ? ($data, $mtime) : $data;
		}
		close $lock;
	}
	return @keys > 1 ? $hashref : undef;
}

sub cache_add {
    shift->cache(@_);
}

sub cache {
    my ($self, $battie, $key, $data, $expire) = @_;
    return if $key =~ tr{a-zA-Z0-9_/:-}{}c;
    $key =~ s{ ^/ }{}x;
    split_numbers(\$key);
    my $dir = $self->get_dir;
    my $file = File::Spec->catfile($dir, "$key.storable");
    my $base = dirname($file);
    unless (-d $base) {
        mkpath([$base], 0, 0755);
    }
    #warn __PACKAGE__." writing to cache $file\n";
    open my $lock, '>', "$dir/lock" or die $!;
    flock $lock, LOCK_EX;
    store($data, $file);
    my $expire_time = time + $expire;
    open my $fh, '>', "$dir/$key.expire" or die $!;
    print $fh $expire_time, $/;
    close $fh;
    close $lock;
}

sub clean_cache {
    my ($self, $battie) = @_;
    my $dir = $self->get_dir;
    my $removed;
    my @dirs;
    find(sub {
            return unless -d $_;
            push @dirs, $File::Find::name;
        }, $dir);
    for my $dir (@dirs) {
        #warn __PACKAGE__.':'.__LINE__.": dir $dir\n";
        my $r = clear_dir($dir);
        $removed += $r;
    }
    warn __PACKAGE__.':'.__LINE__.": removed $removed expired files\n";
}

sub clear_dir {
    my ($dir) = @_;
    my $removed = 0;
    # clean directory from expired storable files
    my $now = time;
    #my $dir = dirname($_);
    open my $lock, '>', "$dir/lock" or die $!;
    flock $lock, LOCK_EX;
    opendir my $dh, $dir or die $!;
    my @files = grep { m/\.(expire)\z/ } readdir $dh;
    #warn __PACKAGE__.':'.__LINE__.": $dir (@files)\n";
    for my $expire (@files) {
        open my $fh, '<', "$dir/$expire" or die $!;
        chomp(my $time = <$fh>);
        close $fh;
        #warn __PACKAGE__.':'.__LINE__.": ($expire) now=$now, expire=$time\n";
        if ($time < $now) {
            unlink "$dir/$expire" or die $!;
            (my $storable = $expire) =~ s/\.expire\z/.storable/;
            unlink "$dir/$storable" or die "Could not delete $dir/$storable: $!";
            $removed += 2;
        }
    }
    close $lock;
    return $removed;
}

sub cache__start {
    my ($self, $battie) = @_;
    my $data = $battie->get_data;
    $data->{cache}->{module} = __PACKAGE__;
}
1;
