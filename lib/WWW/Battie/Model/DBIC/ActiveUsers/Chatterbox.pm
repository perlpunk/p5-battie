package WWW::Battie::Model::DBIC::ActiveUsers::Chatterbox;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);

use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('chatterbox');
__PACKAGE__->add_columns(
    user_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    seq => {
        data_type => 'int',
        size      => '3',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    msg => {
        data_type => 'varchar',
        size      => '256',
        is_nullable => 0,
        is_auto_increment => 0,
        #default_value => ,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
    rec => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 1,
        is_auto_increment => 0,
        default_value => undef,
    },
);

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Model::DBIC::ActiveUsers::Chatterbox::Readonly->new({
            user_id => $self->user_id,
            msg     => $self->msg,
            ctime   => $self->ctime,
            rec     => $self->rec,
            seq     => $self->seq,
        });
}


1;

__END__

