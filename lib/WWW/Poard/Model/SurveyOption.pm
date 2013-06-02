package WWW::Poard::Model::SurveyOption;
# ------- IMPORTANT -----
# if you change / add / remove columns here, please
# update $WWW::Poard::Model::VERSION

use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('survey_option');
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 1,
    },
    position => {
        data_type         => 'int',
        size              => '5',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    survey_id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    answer => {
        data_type         => 'text',
        size              => '',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => '',
    },
    votecount => {
        data_type         => 'int',
        size              => '10',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => 0,
    },
    mtime => {
        data_type     => 'datetime',
        set_on_create => 1,
        set_on_update => 1,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([qw(position survey_id)]);
__PACKAGE__->belongs_to(survey => 'WWW::Poard::Model::Survey','survey_id');


my @acc = qw/ id survey_id answer position votecount ctime mtime /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::SurveyOption::Readonly->new({
        });
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $value = $self->$field;
        $ro->$set( $value );
    }
    return $ro;
}

1;
