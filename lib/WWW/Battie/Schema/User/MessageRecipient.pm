package WWW::Battie::Schema::User::MessageRecipient;
use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('message_recipient');
__PACKAGE__->add_columns(
    message_id => {
        data_type => 'bigint',
        size      => '10',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    recipient_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    has_read => {
        data_type => 'tinyint',
        size      => '1',
        is_nullable => 0,
        is_auto_increment => 0,
    },
);
__PACKAGE__->add_unique_constraint([qw(message_id recipient_id)]);
__PACKAGE__->belongs_to(message => 'WWW::Battie::Schema::User::PMessage','message_id');
__PACKAGE__->belongs_to(recipient => 'WWW::Battie::Schema::User::User','recipient_id');

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Schema::User::MessageRecipient::Readonly->new({
            message_id   => $self->message_id,
            recipient_id => $self->recipient_id,
            has_read     => $self->has_read,
            recipient    => $self->recipient? $self->recipient->readonly : undef,
            message      => $self->message? $self->message->readonly : undef,
        });
}

1;
