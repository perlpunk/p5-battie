package WWW::Battie::Modules::Guest;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module::Model';
use base 'WWW::Battie::Accessor';
__PACKAGE__->follow_good_practice;
__PACKAGE__->mk_accessors(qw/ max_unapproved rows max_entry_length /);
my %functions = (
    functions => {
        guest => {
            start  => 1,
            add   => 1,
            post => 0,
            approve_entry => 1,
            delete_entry => 1,
        },
    },
);
sub functions { %functions }

sub default_actions {
    my ($class, $battie) = @_;
    return {
        guest => [qw/ start add /],
        user  => [qw/ post /],
    };
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        return {
            link => ['guest', 'start'],
            text => $battie->translate('guestbook'),
        };
    };
}


sub model {
    guest => 'WWW::Battie::Schema::Guest',
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    my $self = $class->new({
            max_unapproved => $args->{MAX_UNAPPROVED} || 5,
            max_entry_length => $args->{MAX_ENTRY_LENGTH} || 1024,
            rows => $args->{ROWS} || 10,
        });
}

sub guest__start {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $schema = $self->schema->{guest};
    my $request = $battie->get_request;
    my $data = $battie->get_data;
    my $rows = $self->rows;
    my $page = $request->pagenum(1000);
    my $pages = $battie->module_call(cache => 'from_cache', "guest/pages");
    my ($count, $page_count);
    if ($pages) {
        $count = $pages->{count};
        $page_count = $pages->{page_count};
    }
    else {
        $count = $schema->resultset('Entry')->count;
        $page_count = ($count - ($count % $rows)) / $rows + 1;
        $pages = {
            count => $count,
            page_count => $page_count,
        };
        $battie->module_call(cache => 'cache', "guest/pages", $pages, 60 * 30);
    }
    if ($page > $page_count) {
        $page = $page_count;
    }
    my $entries = $battie->module_call(cache => 'from_cache', "guest/page/$page");
    if ($entries) {
    }
    else {
        my $search = $schema->resultset('Entry')->search(
            {
            },
            {
                order_by => 'ctime DESC',
                rows => $rows,
                page => $page,
            }
        );
        my @entries;
        while (my $entry = $search->next) {
            my $ro = $entry->readonly;
            if ($entry->approved_by) {
                my $user = $battie->module_call(login => 'get_user_by_id', $entry->approved_by);
                $ro->set_approver($user->readonly);
            }
            push @entries, $ro;
        }
        $entries = \@entries;
        $battie->module_call(cache => 'cache', "guest/page/$page", $entries, 60 * 30);
    }
    my $pager = WWW::Battie::Pager->new({
            items_pp => $rows,
            total_count => $count,
            before => 3,
            after => 3,
            current => $page,
            link => $battie->self_url
                . '/guest/start?p=%p'
                ,
            title => '%p',
        })->init;
    $data->{guest}->{entries} = $entries;
    $data->{guest}->{pager} = $pager;
}

sub guest__approve_entry {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $schema = $self->schema->{guest};
    my $request = $battie->get_request;
    my $data = $battie->get_data;
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    my $entry = $schema->resultset('Entry')->find($id);
    $self->exception("Argument", "Entry '$id' does not exist") unless $entry;
    if ($submit->{approve} and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{approve}) {
        my $rows = $self->rows;
        $self->approve_entry($battie, $entry);
        # how many entries are before us?
        my $count = $schema->resultset('Entry')->count({
            ctime => { '>' => $entry->ctime },
        });;
        my $page_count = ($count - ($count % $rows)) / $rows + 1;
        $battie->module_call(cache => 'delete_cache', "guest/page/$page_count");
        if ($request->param('ajax')) {
            my $ro = $entry->readonly;
            if ($entry->approved_by) {
                my $user = $battie->module_call(login => 'get_user_by_id', $entry->approved_by);
                $ro->set_approver($user->readonly);
            }
            $data->{guest}->{entry} = $ro;
            $data->{main_template} = "guest/ajax.html";
            return;
        }
        $battie->set_local_redirect("/guest/start?p=$page_count");
    }
}

sub approve_entry {
    my ($self, $battie, $entry) = @_;
    $entry->update({
        approved_by => $battie->get_session->userid,
        active => 1,
    });
    $battie->writelog($entry);
}

sub guest__delete_entry {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $schema = $self->schema->{guest};
    my $request = $battie->get_request;
    my $data = $battie->get_data;
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    my $entry = $schema->resultset('Entry')->find($id);
    $self->exception("Argument", "Entry '$id' does not exist") unless $entry;
    if ($submit->{delete} and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{delete}) {
        my $rows = $self->rows;
        my $comment = $request->param('comment');
        $comment = '' unless defined $comment;
        $self->delete_entry($battie, $entry, $comment);
        my $count = $schema->resultset('Entry')->count({
            ctime => { '>' => $entry->ctime },
        });;
        my $page_count = ($count - ($count % $rows)) / $rows + 1;
        $battie->module_call(cache => 'delete_cache', "guest/page/$page_count");
        if ($request->param('ajax')) {
            my $ro = $entry->readonly;
            $data->{guest}->{entry} = $ro;
            $data->{main_template} = "guest/ajax.html";
            return;
        }
        $battie->set_local_redirect("/guest/start?p=$page_count");
    }
}

sub delete_entry {
    my ($self, $battie, $entry, $comment) = @_;
    $battie->writelog($entry, $comment);
    $entry->delete;
}

sub guest__add {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    $self->init_db($battie);
    my $schema = $self->schema->{guest};
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    if ($submit->{send} and not $battie->valid_token) {
        $battie->token_exception;
    }
    if ($submit->{preview} or $submit->{send}) {
        my $name = $request->param('name');
        my $url = $request->param('url');
        my $email = $request->param('email');
        my $location = $request->param('location');
        my $message = $request->param('message');
        if (not defined $name or not length $name) {
            $data->{guest}->{error}->{no_name} = 1;
        }
        my $l;
        {
            use bytes; # utf8 maybe more than 1 byte long
            $l = length $message;
        }
        if (not defined $message or not length $message) {
            $data->{guest}->{error}->{no_message} = 1;
        }
        elsif ($l > $self->max_entry_length) {
            $data->{guest}->{error}->{message_too_long} = 1;
        }
        if ($submit->{preview}) {
			my $entry = $schema->resultset('Entry')->new({
				name => $name,
				url => $url,
				email => $email,
				location => $location,
				message => $message,
				active => 1,
				ctime => undef,
			});
			my $ro = $entry->readonly;
			$data->{guest}->{entry} = $ro;
            if ($request->param('ajax')) {
                $data->{main_template} = "guest/ajax.html";
                return;
            }
        }
        if ($submit->{send} and not keys %{ $data->{guest}->{error} }) {
            my $entry = $schema->resultset('Entry')->create({
                name => $name,
                url => $url,
                email => $email,
                location => $location,
                message => $message,
                $battie->get_allow->can_do(guest => 'post') ?
                (active => 1) : (active => 0),
                ctime => undef,
            });
            $battie->writelog($entry);
            $battie->set_local_redirect("/guest/start");
            my $pages = $battie->module_call(cache => 'from_cache', "guest/pages");
            my $page_count = $pages->{page_count};
            for my $i (1 .. $page_count) {
                $battie->module_call(cache => 'delete_cache', "guest/page/$i");
            }
            $battie->module_call(cache => 'delete_cache', "guest/pages");
            return;
        }
        $data->{guest}->{form}->{name} = $name;
        $data->{guest}->{form}->{url} = $url;
        $data->{guest}->{form}->{email} = $email;
        $data->{guest}->{form}->{location} = $location;
        $data->{guest}->{form}->{message} = $message;
    }
}

1;
