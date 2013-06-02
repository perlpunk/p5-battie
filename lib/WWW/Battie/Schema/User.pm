package WWW::Battie::Schema::User;
use strict;
use warnings;
# version:
# 0.00x_00y
# means release x developer version y
our $VERSION = '0.01_032';
use base qw/DBIx::Class::Schema WWW::Battie::Schema/;
use Email::Valid;

my $loaded = 0;
sub load_classes_once {
    unless ($loaded) {
        __PACKAGE__->load_classes();
        $loaded = 1;
    }
}

sub valid_email {
    my ($self, $email) = @_;
    my $valid = Email::Valid->address($email);
    my $tld = Email::Valid->tld($email);
    warn __PACKAGE__." address $email: valid '$valid', tld '$tld'\n";
    return $valid if $valid and $tld;
    return;
}


sub valid_rolename {
    my ($self, $name) = @_;
    return 0 if $name =~ tr/A-Za-z0-9_ -//c
        or $name !~ m/^[A-Za-z0-9].*[A-Za-z0-9]\z/;
    return 1;
}

sub valid_roleid {
    my ($self, $name) = @_;
    return 0 if $name =~ tr/0-9//c;
    return 1;
}
sub valid_userid {
    my ($self, $name) = @_;
    return 0 if $name =~ tr/0-9//c;
    return 1;
}
sub valid_username {
    my ($self, $name) = @_;
    return '' unless defined $name;
    $name =~ s/^\s+//;
    $name =~ s/\s+\z//;
    return '' if (
        $name =~ tr/A-Za-z0-9_.-//c
        || $name !~ m/^[A-Za-z0-9].*[A-Za-z0-9]\z/
        || length($name) > 64
    );

    return $name;
}


sub encrypt {
    my ($self, $pass, $crypted) = @_;
    $crypted ||= ["A".."Z"]->[rand 26] . ["A".."Z"]->[rand 26];
    my $new = crypt($pass, $crypted);
    return $new;
}

sub encrypt_md5 {
    my ($self, $pass, $crypted) = @_;
    unless ($crypted) {
        # create a salt
        $crypted = join '', map {
            ["A".."Z"]->[rand 26]
        } 1 .. 6;
        $crypted = '$1$' . $crypted . '$';
    }
    my $new = crypt($pass, $crypted);
    return $new;
}

sub encrypt_md5_username {
    my ($self, $pass, $crypted, $username) = @_;
    require Digest::MD5;
    my $new = Digest::MD5::md5_hex($pass, lc $username);
    return $new;
}

sub new_token {
    my $md5 = Digest::MD5->new();
    $md5->add($$ , time() , rand(time) );
    return $md5->hexdigest();
}



#--------------------- Readonly classes
{
package WWW::Battie::Schema::User::Postbox::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(id user_id name type is_default ctime mtime messages message_count);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_wo_accessors(@acc);
__PACKAGE__->mk_accessors(qw(user messages message_count));
}

{
package WWW::Battie::Schema::User::Profile::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(user_id name email homepage location signature sex sex_label icq aol yahoo
msn interests avatar birth_year birth_day foto_url ctime mtime rendered_sig geo meta );
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);
    sub geo_lat {
        my $geo = $_[0]->geo or return;
        return (split /\,/, $geo)[0];
    }
    sub geo_long {
        my $geo = $_[0]->geo or return;
        return (split /\,/, $geo)[1];
    }
}

{
package WWW::Battie::Schema::User::Role::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw/ id name rtype actions /;
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Battie::Schema::User::Group::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw/ id name rtype roles /;
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Battie::Schema::User::GroupRole::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw/ group_id role_id /;
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Battie::Schema::User::RoleAction::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw/ id role_id role action /;
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_ro_accessors(@acc);
}

{
package WWW::Battie::Schema::User::Settings::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(user_id messagecount send_notify ctime mtime);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_wo_accessors(@acc);
}

{
package WWW::Battie::Schema::User::Token::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(id id2 user_id ctime mtime);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_wo_accessors(@acc);
sub hidden {
    my ($self) = @_;
    my $id = $self->id;
    my $hidden = qq{<input type="hidden" name="t" value="$id" >};
}
}

{
package WWW::Battie::Schema::User::ActionToken::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(id user_id token action ctime mtime info);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_ro_accessors(@acc);
}

{
package WWW::Battie::Schema::User::User::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(id group_id groupname extra_roles active nick password ctime ctime_epoch mtime settings profile visible roles lastlogin);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Battie::Schema::User::NewUser::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw/ id token email nick password meta ctime mtime /;
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Battie::Schema::User::UserRole::Readonly;
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_ro_accessors(qw(user_id role_id ctime mtime ));

}

{
package WWW::Battie::Schema::User::PMessage::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(id sender message subject recipients has_read read_by copy_of box_id box ctime mtime rendered_message rendered_subject sent_notify sender_user);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_wo_accessors(@acc);
__PACKAGE__->mk_accessors(qw(box read_by sender subject message rendered_message rendered_subject sender_user recipients));
}

{
package WWW::Battie::Schema::User::MessageRecipient::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(message_id recipient_id recipient message has_read);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Battie::Schema::User::Addressbook::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(user_id contactid note blacklist ctime user contact);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->mk_accessors(qw(user contact));
}

{
package WWW::Battie::Schema::User::CGISession::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw(id a_session mtime);
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_ro_accessors(@acc);
}

{
package WWW::Battie::Schema::User::MyNodelet::Readonly;
use base 'Class::Accessor::Fast';
my @acc = qw/ user_id is_open content rendered /;
__PACKAGE__->mk_ro_accessors(@acc);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(@acc);
}

1;
