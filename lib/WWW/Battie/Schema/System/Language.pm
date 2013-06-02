package WWW::Battie::Schema::System::Language;
use base qw/DBIx::Class/;
__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('system_lang');
__PACKAGE__->add_columns(
    id => {
        data_type => 'char',
        size      => '5',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    name => {
        data_type => 'varchar',
        size      => '128',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    fallback => {
        data_type => 'char',
        size      => '5',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    active => {
        data_type => 'tinyint',
        size      => '1',
        is_nullable => 0,
        is_auto_increment => 0,
        default_value => 0,
    },
);
__PACKAGE__->set_primary_key('id');

sub readonly {
    my ($self) = @_;
    my $ro = WWW::Battie::Schema::System::Language::Readonly->new({
            id       => $self->id,
            name     => $self->name,
            fallback => $self->fallback,
            active   => $self->active,
        });
}

1;
