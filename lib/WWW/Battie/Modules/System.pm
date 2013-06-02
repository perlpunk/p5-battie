package WWW::Battie::Modules::System;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module::Model';
use base 'WWW::Battie::Accessor';
use MIME::Lite;
__PACKAGE__->follow_good_practice;
__PACKAGE__->mk_accessors(qw/ terms /);
my %functions = (
    functions => {
        system => {
            start       => 1,
            language    => 1,
            translation => 1,
            terms       => 1,
            edit_term   => 1,
            term        => 1
        },
    },
);
sub functions { %functions }

sub default_actions {
    my ($class, $battie) = @_;
    return {
        guest => [qw/ term /],
    };
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        my @links;
        my $allow = $battie->get_allow;
        if ($allow->can_do(system => 'start')) {
            push @links, {
                link => ['system', 'start'],
                text => 'System',
            };
        }
        if ($allow->can_do(system => 'term')) {
            push @links, {
                link => ['system', 'term'],
                text => $battie->translate('global_terms_conditions'),
            };
        }
        return @links;
    };
}

sub model {
    system => 'WWW::Battie::Schema::System',
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    my $self = $class->new({
            terms => [split /[ ,]/, ($args->{TERMS} || '')],
        });
}

sub system__terms {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->request;
    my $args = $request->args;
    my ($id) = @$args;
    my $schema = $self->schema->{system};
    my $data = $battie->get_data;
    my @list;
    if ($id) {
        @list = $schema->resultset('Terms')->search({
                id => $id,
            }, {
                order_by => 'start_date desc',
            })->all;
        $data->{system}->{list_revisions} = 1;
    }
    else {
        @list = $schema->resultset('Terms')->search({
            }, {
                group_by => 'id',
            })->all;
    }
    $data->{system}->{terms} = [map $_->readonly, @list];
}

sub system__edit_term {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{system};
    my $request = $battie->request;
    my $args = $request->args;
    my ($id, $start_date) = @$args;
    if ($start_date) {
        $start_date = $self->create_dt($start_date);
    }
    my $term;
    my $term_ro;
    if ($id && $start_date) {
        $term = $schema->resultset('Terms')->find({ id => $id, start_date => $start_date })
                or $battie->exception(Argument => "Terms '$id' does not exist");
    }
    elsif ($id) {
        $term = $schema->resultset('Terms')->search({
                id  => $id,
            }, {
                order_by    => 'start_date desc',
                rows        => 1,
            })->single
            or $battie->exception(Argument => "Terms '$id' does not exist");
    }
    my $now = DateTime->now;
    if ($term) {
        $term_ro = $term->readonly;
        if ($term_ro->start_date <= $now) {
            $term_ro->set_active(1);
        }
    }
    my $submit = $request->get_submit;
    if ($submit->{save}) {
        $battie->require_token;
        # TODO validate
        my $name = $request->param('term.name');
        my $date = $request->param('term.start_date');
        my $content = $request->param('term.content');
        my $start_date = $self->create_dt($date);
        my $format = $request->param('term.style');
        if ($start_date) {
            $date = $start_date;
        }
        else {
            $self->exception(Argument => "Invalid date format '$date'");
        }
        my %update = (
            name        => $name,
            start_date  => $date,
            style       => $format,
            content     => $content,
        );
        if (!$term_ro or $term_ro->active) {
            # cannot change, create new revision
            if ($term_ro and $start_date <= $term->start_date) {
                $self->exception(Argument => "Please set new date");
            }
            my $id = $request->param('term.id');
            $term = $schema->resultset('Terms')->create({
                    id => $id,
                    %update,
                });
        }
        else {
            $term->update({
                    %update,
                });
        }
        my $ck = "system/terms/$id";
        $battie->delete_cache("$ck/0" . $battie->session->userid);
        $battie->delete_cache("$ck/" . $term->start_date . $battie->session->userid);
        $battie->set_local_redirect('/system/edit_term/' . $term->id);
    }
    my $data = $battie->get_data;
    if ($term_ro) {
        my $html = $self->render_textile($battie, $term_ro->content);
        $term_ro->set_rendered($html);
        $data->{system}->{term} = $term_ro;
    }
}

sub add_term_user {
    my ($self, $battie, %args) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{system};
    my $terms = $args{terms};
    my $uid = $args{user_id};
    for my $id (keys %$terms) {
        my $start_date = $terms->{$id};
        $start_date = $self->create_dt($start_date)
            or next;
            $schema->resultset('TermUser')->create({
                    user_id => $uid,
                    term_id => $id,
                    start_date  => $start_date,
            });
        }
}

# show current active terms or older
# for guests
sub system__term {
    my ($self, $battie) = @_;
    $self->load_db($battie);
    my $request = $battie->request;
    my $args = $request->args;
    my ($id, $start_date) = @$args;
    if ($start_date) {
        $start_date = $self->create_dt($start_date);
    }
    my $term;
    my $data = $battie->get_data;
    my $now = DateTime->now;
    if ($id and grep $_ eq $id, @{ $self->terms }) {
        my $term_ro;
        my $ck;
        my $cached = 1;
        if ($start_date) {
            if ($start_date > $now) {
                $battie->exception(Argument => "Terms '$id/$start_date' does not exist");
            }
            $term_ro = $self->fetch_term($battie, $id, $start_date);
        }
        else {
            $term_ro = $self->fetch_term($battie, $id);
        }
        $data->{system}->{term} = $term_ro;
    }
    else {
        my $terms = $self->fetch_active_terms($battie);
        $data->{system}->{active_terms} = [sort { $a->id cmp $b->id } values %$terms];
    }
}

sub fetch_active_terms {
    my ($self, $battie) = @_;
    my %terms;
    for my $id (@{ $self->terms }) {
        my $term = eval { $self->fetch_term($battie, $id) }
            or next;
        $terms{ $id } = $term;
    }
    return \%terms;
}
sub fetch_term {
    my ($self, $battie, $id, $start_date) = @_;
    $self->init_db($battie);
    my $ck;
    my $cached = 1;
    my $term_ro;
    my $schema = $self->schema->{system};
    my $term;
    if ($start_date) {
        $ck = "system/terms/$id/$start_date";
        $term_ro = $battie->from_cache($ck);
        unless ($term_ro) {
            $term = $schema->resultset('Terms')->find({ id => $id, start_date => $start_date })
                or $battie->exception(Argument => "Terms '$id' does not exist");
            $cached = 0;
        }
    }
    else {
        $ck = "system/terms/$id/0";
        $term_ro = $battie->from_cache($ck);
        my $now = DateTime->now;
        unless ($term_ro) {
            $term = $schema->resultset('Terms')->search({
                    id  => $id,
                    start_date => { '<=', $now },
                }, {
                    order_by    => 'start_date desc',
                    rows    => 1,
                })->single
                or $battie->exception(Argument => "Terms '$id' does not exist");
            $cached = 0;
        }
    }
    unless ($cached) {
        $term_ro = $term->readonly;
        my $html = $self->render_textile($battie, $term_ro->content);
        $term_ro->set_rendered($html);
        $battie->to_cache($ck, $term_ro, 60 * 10);
    }
    return $term_ro;
}

sub system__start {
}

sub fetch_languages {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{system};
    my @languages = $schema->resultset('Language')->search({
            active => 1,
        },
        {
            order_by => 'id',
        },
    )->all;
    return @languages;
}

sub system__language {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    $self->init_db($battie);
    my $schema = $self->schema->{system};
    my @languages = $schema->resultset('Language')->search({},
        {
            order_by => 'id',
        },
    )->all;
    if ($submit->{add}) {
        $battie->token_exception unless $battie->valid_token;
        my $id = $request->param('id');
        my $name = $request->param('name');
        my $fallback = $request->param('fallback');
        my $lang = $schema->resultset('Language')->create({
            id       => $id,
            name     => $name,
            fallback => $fallback,
            active   => 0,
        });
        $battie->set_local_redirect('/system/language');
        return;
    }
    elsif ($submit->{save}) {
        $battie->token_exception unless $battie->valid_token;
        for my $lang (@languages) {
            my $active = $request->param("active." . $lang->id) ? 1 : 0;
            warn __PACKAGE__.':'.__LINE__.": active $active\n";
            if ($lang->active != $active) {
                $lang->update({ active => $active });
            }
        }
        $battie->set_local_redirect('/system/language');
        return;
    }
    my $data = $battie->get_data;
    @languages = map { $_->readonly } @languages;
    $data->{system}->{languages} = [@languages];
    $data->{system}->{form}->{languages} = [undef, map { [$_->id, $_->name . ' ' . $_->id] } @languages];
}

sub system__translation {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    $self->init_db($battie);
    my $schema = $self->schema->{system};
    if ($submit->{add}) {
        $battie->token_exception unless $battie->valid_token;
        my $id = $request->param('id');
        my $language = $request->param('language');
        my $text = $request->param('translation');
        my $exists = $schema->resultset('Translation')->search({
            id       => $id,
            lang     => $language,
        })->single;
        if ($exists) {
            $self->exception("Argument", "ID/Language already exists");
        }
        my $lang = $schema->resultset('Translation')->create({
            id       => $id,
            lang     => $language,
            translation => $text,
        });
        $battie->set_local_redirect('/system/translation');
        return;
    }
    my @languages = $schema->resultset('Language')->search({},
        {
            order_by => 'id',
        },
    )->all;
    my $data = $battie->get_data;
    @languages = map { $_->readonly } @languages;
    $data->{system}->{languages} = [@languages];
    $data->{system}->{form}->{languages} = [undef, map { [$_->id, $_->name . ' ' . $_->id] } @languages];
    my $rows = 30;
    my $page = 1;
    my ($search, $count_ref) = $schema->count_search(Translation =>
        { },
        {
            rows => $rows,
            page => $page,
            order_by => 'id',
            group_by => 'id',
        },
    );
    my @trans;
    while (my $trans = $search->next) {
        push @trans, $trans->readonly;
    }
    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@trans], ['trans']);
    $data->{system}->{translations} = [@trans];
}

sub fetch_translations {
    my ($self, $battie, $lang) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{system};
    my $map = $battie->module_call(cache => 'from_cache', 'system/trans2/' . $lang);
    unless ($map) {
        my $search = $schema->resultset('Translation')->search({
            lang     => $lang,
        });
        my $translations = [];
        while (my $trans = $search->next) {
            push @$translations, $trans->readonly;
        }
        $map = {map { ($_->id, [$_->translation, $_->plural])  } @$translations};
        $battie->module_call(cache => 'cache', 'system/trans2/' . $lang, $map, 60 * 60 * 5);
    }
    return $map;
}

sub add_translation_data {
    my ($self, $battie, $data, $args) = @_;
    $self->init_db($battie);
    my $schema = $self->schema->{system};
    my $overwrite = $args->{overwrite} || 1;
    for my $row (@$data) {
        my $exists = $schema->resultset('Translation')->search({
            lang => $row->[0],
            id => $row->[1],
        })->single;
        if ($overwrite and $exists) {
            $schema->resultset('Translation')->search({
                lang => $row->[0],
                id => $row->[1],
            })->delete;
        }
        if (!$exists or $overwrite) {
            $schema->resultset('Translation')->create({
                lang        => $row->[0],
                id          => $row->[1],
                translation => $row->[2],
                plural      => $row->[3],
            });
        }
    }
}

sub render_textile {
    my ($self, $battie, $text) = @_;
    my $textile = $battie->new_textile;
    $textile->disable_html(1);
    my $html = $textile->process($text);
    return $html;
}

sub create_dt {
    my ($self, $date) = @_;
    if ($date =~ m/^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}):(\d{2}))?/) {
        my ($year, $month, $day, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);
        eval {
            $date = DateTime->new(
                year    => $year,
                month   => $month,
                day     => $day,
                hour    => $hour||0,
                minute  => $min||0,
                second  => $sec||0,
            );
        };
        return $date unless $@;
    }
    return;
}

1;
