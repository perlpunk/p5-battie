package WWW::Poard::Model;
use strict;
use warnings;
# version:
# 0.00x_00y
# means release x developer version y
our $VERSION = '0.01_024';
use base qw/DBIx::Class::Schema/;

my $loaded = 0;
sub load_classes_once {
    unless ($loaded) {
        __PACKAGE__->load_classes();
        $loaded = 1;
    }
}


#--------------------- Readonly classes
{
package WWW::Poard::Model::Board::Readonly;
    use base qw/ WWW::Battie::Accessor WWW::Battie::Nested /;
    my @acc = qw/ id name description position parent_id containmessages
    grouprequired ctime mtime latest sub_boards thread_count answer_count
    is_expanded level is_last is_first level_down meta parent_ids /;
    __PACKAGE__->follow_good_practice;
    __PACKAGE__->mk_accessors(@acc);
    __PACKAGE__->create_bits(flags => [qw/ index archive /]);
sub children_count {
    return ($_[0]->get_rgt - $_[0]->get_lft - 1) / 2
}
}

{
package WWW::Poard::Model::ReadMessages::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = qw/ thread_id user_id position mtime meta mtime_epoch /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Poard::Model::ArchivedMessage::Readonly;
    use base qw/ WWW::Battie::Accessor /;
    my @acc = qw/ id msg_id thread_id message lasteditor_id ctime /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Poard::Model::MessageLog::Readonly;
    use base qw/ WWW::Battie::Accessor /;
    my @acc = qw/ log_id message_id action comment user_id ctime user /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Poard::Model::Message::Readonly;
    use base 'Class::Accessor::Fast';
    use base qw/ WWW::Battie::Accessor WWW::Battie::Nested /;
    my @acc = qw/
        sub_boards author message rendered rendered_sig author_name
        is_editable lasteditor thread logs approved_by id thread_id author_id
        position status ctime mtime lft rgt level hidden_messages is_last level_down
        score score_list is_new old_branch is_selectable age_level title leaf_posting
        changelog has_attachment attachments
        ctime_epoch mtime_epoch
    /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);

    sub is_approved {
        $_[0]->get_status eq 'active'
    }
    sub is_onhold {
        $_[0]->get_status eq 'onhold'
    }
    sub is_deleted {
        $_[0]->get_status eq 'deleted'
    }
    sub is_leaf {
        $_[0]->lft + 1 == $_[0]->rgt
    }
    sub is_root { $_[0]->lft == 1 }
}

{
package WWW::Poard::Model::Attachment::Readonly;
    use base 'Class::Accessor::Fast';
    use base qw/ WWW::Battie::Accessor WWW::Battie::Nested /;
    my @acc = qw/
        message_id attach_id type filename meta size deleted thumb ctime mtime
        thumbnail_url
    /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);

}


{
package WWW::Poard::Model::Survey::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = qw(id thread_id question total_votecount votecount is_multiple status options thread ctime mtime has_voted);
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_wo_accessors(@acc);
    __PACKAGE__->mk_accessors(qw/ options thread has_voted total_votecount /);
    sub closed { $_[0]->status eq 'closed' }
}

{
package WWW::Poard::Model::SurveyOption::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = qw/ id survey_id answer position votecount percent survey percent ctime mtime myvote /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_wo_accessors(@acc);
    __PACKAGE__->mk_accessors(qw(survey percent));
}

{
package WWW::Poard::Model::SurveyVote::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = qw(id survey_id survey meta user_id ctime);
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_wo_accessors(@acc);
    __PACKAGE__->mk_accessors(qw(survey));
}

{
package WWW::Poard::Model::Thread::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = qw/
        id title author_id status fixed board_id read_count messagecount
        ctime mtime closed board last first is_survey surveys author
        board messages approved_by author_name meta subtrees
        last first surveys is_read last_read is_tree
        own solved logs tags readers subscribed
        ctime_epoch mtime_epoch
    /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);
    sub is_approved { $_[0]->get_status eq 'active' }
    sub is_onhold   { $_[0]->get_status eq 'onhold' }
    sub is_deleted  { $_[0]->get_status eq 'deleted' }
}

{
package WWW::Poard::Model::Tag::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = qw/
        id name
    /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Poard::Model::ThreadTag::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = qw/
        tag_id thread_id
    /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);
}

{
package WWW::Poard::Model::UserTag::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = qw/
        tag_id user_id ctime
    /;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);
}


{
package WWW::Poard::Model::Trash::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = qw(id thread_id msid comment ctime mtime deleted_by message thread user);
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->mk_accessors(qw(deleted_by message thread user));
}

{
package WWW::Poard::Model::Notify::Readonly;
    use base 'Class::Accessor::Fast';
    my @acc = qw(id user_id thread_id msg_id last_notified ctime thread);
    __PACKAGE__->mk_ro_accessors(@acc);
    __PACKAGE__->follow_best_practice;
    __PACKAGE__->mk_accessors(@acc);
}

1;
