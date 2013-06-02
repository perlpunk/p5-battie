package WWW::Battie::Model::DBIC::ActiveUsers;
our $VERSION = '0.05';
use base qw/DBIx::Class::Schema/;
use Digest::MD5 ();

my $loaded = 0;
sub load_classes_once {
    unless ($loaded) {
        __PACKAGE__->load_classes();
        $loaded = 1;
    }
}

sub generate_sid {
    my $md5 = Digest::MD5->new;
    $md5->add($$ , time() , rand(time) );                                                                 
    my $md52 = Digest::MD5->new;
    $md52->add(rand($$) , time() , rand(time) );
    return $md5->hexdigest . $md52->hexdigest;
}

{
    package WWW::Battie::Model::DBIC::ActiveUsers::Chatterbox::Readonly;
    use POSIX qw/ strftime /;
    use base 'Class::Accessor::Fast';
    my @acc = qw/ user_id ctime msg action user self rendered seq ctime_epoch /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);

    sub ltime {
        my ($ctime) = $_[0]->ctime;
        strftime("%H:%M:%S", reverse (split /\D/, $ctime));
    }
}

{
    package WWW::Battie::Model::DBIC::ActiveUsers::Session::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = (qw/ id user_id data ctime mtime expires /);
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);

    sub remote_addr {
        return $_[0]->data->{remote_addr};
    }
    sub token {
        return $_[0]->data->{token};
    }
    sub hidden {
        return $_[0]->data->{hidden};
    }
	sub terms_to_accept {
        return $_[0]->data->{terms};
	}
}


1;
