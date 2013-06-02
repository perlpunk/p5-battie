package WWW::Battie::Schema::System::Translation;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('system_translation');
__PACKAGE__->add_columns(
    id => {
        data_type => 'varchar',
        size      => '128',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    lang => {
        data_type => 'char',
        size      => '5',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    translation => {
        data_type => 'text',
        size      => '',
        is_nullable => 0,
        is_auto_increment => 0,
        #default_value => ,
    },
    plural => {
        data_type => 'text',
        size      => '',
        is_nullable => 1,
        is_auto_increment => 0,
        #default_value => ,
    },
);
__PACKAGE__->add_unique_constraint([qw/ id lang /]);

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Schema::System::Translation::Readonly->new({
            id          => $self->id,
            lang        => $self->lang,
            translation => $self->translation,
            plural      => $self->plural,
        });
}

1;
