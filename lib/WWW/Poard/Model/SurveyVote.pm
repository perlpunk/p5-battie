package WWW::Poard::Model::SurveyVote;
# ------- IMPORTANT -----
# if you change / add / remove columns here, please
# update $WWW::Poard::Model::VERSION

use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto InflateColumn::Serializer Core /);
__PACKAGE__->table('survey_vote');
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 1,
    },
    user_id => {
        data_type => 'bigint',
        size      => '20',
        is_nullable => 0,
        is_auto_increment => 0,
    },
    survey_id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    meta => {
        data_type           => 'text',
        serializer_class    => 'JSON',
        is_nullable         => 0,
        default_value       => '',
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([qw(user_id survey_id)]);
__PACKAGE__->belongs_to(survey => 'WWW::Poard::Model::Survey','survey_id');


my @acc = qw/ id survey_id meta user_id ctime /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::SurveyVote::Readonly->new({
        });
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $value = $self->$field;
        $ro->$set( $value );
    }
    return $ro;
}

1;
