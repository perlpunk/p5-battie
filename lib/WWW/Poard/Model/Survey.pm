package WWW::Poard::Model::Survey;
# ------- IMPORTANT -----
# if you change / add / remove columns here, please
# update $WWW::Poard::Model::VERSION

use base qw/DBIx::Class/;
use Digest::MD5;
__PACKAGE__->load_components(qw/ TimeStamp PK::Auto Core /);
__PACKAGE__->table('survey');
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 1,
    },
    thread_id => {
        data_type         => 'bigint',
        size              => '20',
        is_nullable       => 0,
        is_auto_increment => 0,
    },
    question => {
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

    # holds the number of allowed answers (0 for
    # one allowed answer)
    is_multiple => {
        data_type         => 'int',
        size              => '5',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => 0,
    },
    status => {
        data_type         => "ENUM('onhold','active','deleted','closed')",
        size              => '',
        is_nullable       => 0,
        is_auto_increment => 0,
        default_value     => 'onhold',
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
__PACKAGE__->belongs_to(thread => 'WWW::Poard::Model::Thread','thread_id');
__PACKAGE__->has_many('options' => 'WWW::Poard::Model::SurveyOption', 'survey_id');


my @acc = qw/ id thread_id question votecount is_multiple status options ctime mtime /;
sub readonly {
    my ($self, $select) = @_;
    my $ro = WWW::Poard::Model::Survey::Readonly->new({
        });
    for my $field (@{ $select || [@acc] }) {
        my $set = "set_$field";
        my $value = $self->$field;
        $ro->$set( $value );
    }
    return $ro;
}

1;
