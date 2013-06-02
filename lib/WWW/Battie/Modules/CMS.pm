package WWW::Battie::Modules::CMS;
use strict;
use warnings;
use Carp qw(carp croak);
use base 'WWW::Battie::Module::Model';
use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(dir url));
use File::Basename;
use File::Spec;
use File::Path;
use HTML::Entities;
use DateTime;
my %functions = (
    functions => {
        cms => {
            start             => 1,
            edit_page_textile => 1,
            set_page          => 1,
            delete_page       => 1,
            set_markup        => 1,
            list_dates        => 1,

            show_content      => 1,
            create_dir        => 1,
            upload_content    => 1,
            delete_content    => 1,
            rename_file       => 1,

            edit_motd       => 1,
            list_motd       => 1,
        },
    },
);
sub functions { %functions }
sub model {
    content => 'WWW::Battie::Model::DBIC::Content'
}

sub navi {
    sub {
        my ($self, $battie, $args) = @_;
        return {
            link => ['cms', 'start'],
            text => 'Content Management',
        };
    };
}

sub from_ini {
    my ($class, $battie, $args) = @_;
    my $url = $args->{URL};
    my $dir = $battie->get_paths->{docroot} . $url;
    my $self = $class->new({
            dir => $dir,
            url => $url,
        });
}

sub get_path_from_request {
    my ($self, $args) = @_;
    my $dir = $self->get_dir;
    return ($dir, '', $dir) unless @$args;
    my @paths = join '/', grep $self->valid_filename($_), @$args;
    my $filename = File::Spec->catfile(@paths);
    $self->exception("Argument", "No absolute filenames")
        if File::Spec->file_name_is_absolute($filename);
    my $fullpath = File::Spec->catfile($dir, $filename);
    return ($dir, $filename, $fullpath);
}

sub cms__rename_file {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args = $request->get_args;
    my ($path, $filename, $fullpath) = $self->get_path_from_request($args);
    $self->exception("Argument", "No such file or directory '$filename'")
        unless -e $fullpath;
    my $data = $battie->get_data;
    my $submit = $request->get_submit;
    my $basename = basename $filename;
    if ($submit->{rename}) {
        my $new = $request->param('new_filename');
        $self->exception("Argument", "Not a valid filename $new") unless $self->valid_filename($new);
        my $dirname = dirname $filename;
        my $full_new = File::Spec->catfile($path, $dirname, $new);
        $self->exception("Argument", "$basename does not exist") unless -f $fullpath;
        $self->exception("Argument", "$new does already exist") if -f $full_new;
        my $ok = rename($fullpath, $full_new) or $self->exception("Argument", "Could not rename");
        $self->exception("Argument", "Could not rename: $!") unless $ok;
        my @replace_pages = $request->param('replace_page');
        if (@replace_pages) {
            $self->init_db($battie);
            my $schema = $self->schema->{content};
            my @pages = $schema->resultset('Page')->find({
                id => { IN => [@replace_pages] },
            });
            for my $page (@pages) {
                my $text = $page->text;
                if ($text =~ s#content:/$filename#content:/$dirname/$new#g) {
                    $page->update({ text => $text });
                }
            }
        }
        $battie->set_local_redirect('/cms/show_content/' . $dirname);
        return;
    }
    $self->init_db($battie);
    my $schema = $self->schema->{content};
    my $search = $schema->resultset('Page')->search(
        {
            text => { LIKE => "%content:/$filename%" },
        },
        {
            order_by => 'title',
        },
    );
    my @linking;
    while (my $page = $search->next) {
        push @linking, $page->readonly;
    }
    $data->{cms}->{linking_pages} = \@linking;
    $data->{cms}->{filename} = $basename;
    $data->{cms}->{fullpath} = $filename;
}

sub valid_filename {
    my ($self, $name) = @_;
    return 1 if $name =~ m/^[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)?\z/;
    return 0;
}

sub cms__delete_content {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args = $request->get_args;
    my $dir = $self->get_dir;
    my @paths = File::Spec->no_upwards(@$args);
    my $path = File::Spec->catfile(@paths);
    $self->exception("Argument", "No absolute filenames")
        if File::Spec->file_name_is_absolute($path);
    my $filename = File::Spec->catfile($dir, @paths ? $path : ());
    $self->exception("Argument", "No such file or directory '$path'")
        unless -e $filename;
    my @files = $request->param('cms.file');
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    if ($submit->{delete} and not $battie->valid_token) {
        $data->{cms}->{error}->{token} = 1;
        delete $submit->{delete};
    }
    if ($submit->{delete}) {
        my @delete = grep { !m#/# } @files;
        @delete = grep { -e $_ } map { File::Spec->catfile($filename, $_) } @delete;
        warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@files], ['files']);
        my $error = '';
        my $success = '';
        for my $file (@delete) {
            if (unlink($file)) {
                $success .= "Deleted '$file'\n";
            }
            else {
                $error .= "Error deleting '$file': $!\n";
            }
        }
        if ($error) {
            $data->{cms}->{error}->{delete} = $error;
        }
        else {
            $battie->set_local_redirect('/cms/show_content/' . $path);
        }
    }
}

sub cms__show_content {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args = $request->get_args;
    my $dir = $self->get_dir;
    my @paths = File::Spec->no_upwards(@$args);
    my $path = File::Spec->catfile(@paths);
    $self->exception("Argument", "No absolute filenames")
        if File::Spec->file_name_is_absolute($path);
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@paths], ['paths']);
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$path], ['path']);
    my $filename = File::Spec->catfile($dir, @paths ? $path : ());
    $self->exception("Argument", "No such file or directory '$path'")
        unless -e $filename;
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$filename], ['filename']);
    my $data = $battie->get_data;
    my %opened = map { $_ => 1 } $request->param('opened');
    if (my $open = $request->param('open')) {
        $opened{$open} = 1;
    }
    elsif (my $close = $request->param('close')) {
        delete $opened{$close};
    }
    $data->{cms}->{opened} = join ';', map {
        'opened=' . encode_entities($_)
    } keys %opened;
    #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%opened], ['opened']);
    if (-d $filename) {
        opendir my $dh, $filename or die $!;
        my (@files, @dirs);
        while (my $f = readdir $dh) {
            next if $f =~ m/^\./;
            local $_ = "$filename/$f";
            if (-f $_) {
                push @files, $f;
            }
            if(-d $_) {
                push @dirs, $f;
            }
        }
        closedir $dh;
        $data->{cms}->{path} = $path;
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@files], ['files']);
        #warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@dirs], ['dirs']);
        my $fullpath = '';
        for my $base (@paths) {
            $fullpath .= "$base/";
            push @{ $data->{cms}->{paths} }, {
                basename => $base,
                fullname => $fullpath,
            };
        }
        $data->{cms}->{files} = [sort @files];
        $data->{cms}->{dirs} = [sort @dirs];
    }
    elsif (-f $filename) {
    }
}

sub cms__upload_content {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args = $request->get_args;
    my $dir = $self->get_dir;
    my @paths = File::Spec->no_upwards(@$args);
    my $path = File::Spec->catfile(@paths);
    $self->exception("Argument", "No absolute filenames")
        if File::Spec->file_name_is_absolute($path);
    my $filename = File::Spec->catfile($dir, $path);
    $self->exception("Argument", "No such file or directory '$path'")
        unless -e $filename;
    my $data = $battie->get_data;
    my $submit = $request->get_submit;
    if ($submit->{upload} and not $battie->valid_token) {
        delete $submit->{upload};
        $data->{cms}->{error}->{token} = 1;
    }
    if ($submit->{upload}) {
        my $upload = $request->get_cgi->upload("file");
        my $filename = $request->get_cgi->upload("file");
        $filename =~ tr/a-zA-Z0-9_.-//cd;
        $self->exception("Argument", "Wrong path") if $filename =~ m/^\./;
        open my $ifh, '>', "$dir/$path/$filename" or die $!;
        while (my $line = <$upload>) {
            print $ifh $line;
        }
        close $ifh;
        $battie->set_local_redirect('/cms/show_content/' . $path);
    }
    $data->{cms}->{path} = $path;
}

sub cms__create_dir {
    my ($self, $battie) = @_;
    my $request = $battie->request;
    my $args = $request->get_args;
    my $dir = $self->get_dir;
    my @paths = File::Spec->no_upwards(@$args);
    my $path = File::Spec->catfile(@paths);
    my $submit = $request->get_submit;
    $self->exception("Argument", "No absolute filenames: '$path'")
        if File::Spec->file_name_is_absolute($path);
    my $newdir = $request->param('newdir');
    $self->exception("Argument", "Only [a-zA-Z0-9_-] allowed")
        if $newdir =~ tr/a-zA-Z0-9_-//c;
    my $data = $battie->get_data;
    my $old_filename = File::Spec->catfile($dir, $path);
    my $filename = File::Spec->catfile($dir, $path, $newdir);
    $self->exception("Argument", "No such file or directory '$path'")
        unless -e $old_filename;
    if ($submit->{create} and not $battie->valid_token) {
        delete $submit->{create};
        $data->{cms}->{error}->{token} = 1;
    }
    if ($submit->{create}) {
        my $newpath = (length $path ? $path . '/' : '') . $newdir;
        $self->exception("Argument", "'$filename' already exists") if -e $filename;
        # TODO permissions (from config?)
        mkpath([$filename], 0, 0711);
        $battie->set_local_redirect('/cms/show_content/' . $newpath);
        return;
    }
    $data->{cms}->{newdir} = $newdir;
}

sub cms__list_dates {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
		my $matrix = $self->make_calender_month(2007,2,15);
		my $data = $battie->get_data;
		$data->{cms}->{month_table} = $matrix;
		$data->{cms}->{month} = 2;
		$data->{cms}->{year} = 2007;
		$data->{cms}->{day} = 15;
}

sub make_calender_month {
		my ($self, $year, $month, $current_day) = @_;
		my $offset = 0;
		use Time::Local;
		my $time = timelocal(0,0,12,1,$month,$year);
		my ($wday, $yday) = (localtime $time)[6,7];
		my $m_later = Time::Local::timelocal_nocheck(0,0,12,1,$month+1,$year);
		$m_later -= 60*60*24;
		my ($max_day) = (localtime $m_later)[3];
		$offset = $wday-1;
		my $week_num = 0;
		my @matrix;
		$month++; $year += 1900;
		for my $day (1..$max_day) {
				#warn __PACKAGE__." matrix[$week_num]->[$offset] = '$year-$month-$day'\n";
				#$matrix[$week_num]->{days}->[$offset] = "$year-$month-$day";
				$matrix[$week_num]->{days}->[$offset] = {
						day => sprintf ("%02d", $day),
						current => $day == $current_day ? 1 : 0,
				};
				if ((1+$offset) % 7 == 0) {
						$week_num++;
						$offset = -1;
				}
				$offset++;
		}
		$#{ $matrix[-1]->{days} } = 6;
		#warn __PACKAGE__.$".Data::Dumper->Dump([\@matrix], ['matrix']);
		return \@matrix;
}

sub cms__start {
    my ($self, $battie) = @_;
    my $request = $battie->get_request;
    my $args = $request->get_args;

}

sub cms__delete_page {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->exception("Argument", "Not a valid page id") if $id =~ tr/0-9//c;
    my $submit = $request->get_submit;
    my $data = $battie->get_data;
    if ($submit->{delete} and not $battie->valid_token) {
        delete $submit->{delete};
        $data->{cms}->{error}->{token} = 1;
    }

}

sub cms__set_markup {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->exception("Argument", "Not a valid page id") if $id =~ tr/0-9//c;
    my $data = $battie->get_data;
    my $schema = $self->get_schema->{content};
    my $page_rs = $schema->resultset('Page');
    my $page = $page_rs->find($id);
    my $submit = $request->get_submit;
    if ($submit->{set} and not $battie->valid_token) {
        delete $submit->{set};
        $data->{cms}->{error}->{token} = 1;
    }
    $data->{cms}->{page} = $page->readonly;
    $data->{cms}->{markup_options} = [
        $page->markup, map { [$_, $_] } qw(html textile)
    ];
}

sub cms__set_page {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    $self->exception("Argument", "Not enough arguments") unless @$args;
    my ($id) = @$args;
    $self->exception("Argument", "Not a valid page id") if $id =~ tr/0-9//c;
    my $pid = $request->param('page.parent') || 0;
    my $schema = $self->get_schema->{content};
    my $page_rs = $schema->resultset('Page');
    my $page = $page_rs->find($id);
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$page], ['page']);
    my $data = $battie->get_data;
    $data->{page} = $page->readonly;
    $data->{pid} = $pid;
    my $all_pages = $page_rs->search(
        {
            position => { '>' => 0 },
            parent => $pid,
            id => { '!=' => $id },
        },
        {
            order_by => 'position',
        },
    );
    while (my $p = $all_pages->next) {
        #warn __PACKAGE__.$".Data::Dumper->Dump([\$p], ['p']);
        my $id = $p->id;
        #warn __PACKAGE__.$".Data::Dumper->Dump([\$id], ['id']);
        #$data->{pages}->[$p->position] = $p->readonly;
        push @{ $data->{pages} }, $p->readonly;
    }
    my $submit = $request->get_submit;
    # TODO $battie->valid_token
    if ($submit->{save} and not $battie->valid_token) {
        delete $submit->{save};
        $data->{cms}->{error}->{token} = 1;
    }
    if ($submit->{save}) {
        my $position = $request->param('page.position');
        $page->position($position + 1);
        $page->parent($pid);
        $page->update;
        #warn __PACKAGE__." --- $schema, $page->parent\n";
        WWW::Battie::Model::DBIC::Content->reposition_childs($schema, $page->parent);
        my $ck = "content/pagenavi/" . $page->url;
        $battie->delete_cache($ck);
        while (my $parent_id = $page->parent) {
            warn __PACKAGE__.':'.__LINE__.": find parent $parent_id\n";
            my $parent = $page_rs->find($parent_id);
            my $ck = "content/pagenavi/" . $parent->url;
            $battie->delete_cache($ck);
            $page = $parent;
        }
    }
}

sub cms__edit_page_textile {
    my ($self, $battie) = @_;
    $self->init_db($battie);
    my $request = $battie->get_request;
    my $args = $request->get_args;
    my $id;
    my $edit_page;
    my $schema = $self->get_schema->{content};
    my $data = $battie->get_data;
    my $page_rs = $schema->resultset('Page');
    my $parent = $request->param('cms.parent_id') || 0;
    #warn __PACKAGE__.$".Data::Dumper->Dump([\$parent], ['parent']);
    $data->{cms}->{parent} = $parent;
    if (@$args) {
        # we edit an existing page
        ($id) = @$args;
        $self->exception("Argument", "Not a valid page id") if $id =~ tr/0-9//c;
        $edit_page = $page_rs->find($id);
        #warn __PACKAGE__.$".Data::Dumper->Dump([\$edit_page], ['edit_page']);
        $data->{cms}->{page} = $edit_page->readonly;
    }
    my $submit = $request->get_submit;
    if ($submit->{save}) {
        $battie->require_token;
    }
    if ($submit->{preview} or $submit->{save}) {
        my $text = $request->param('cms.text');
        my $url = $request->param('cms.url');
        $self->exception("Argument", "'$url' is not a valid link (only use a-z, 0-9 and _)")
            unless WWW::Battie::Model::DBIC::Content->valid_link($url);
        my $title = $request->param('cms.title');
        $self->exception("Argument", "'$title' is not a valid title (only up to 64 characters)")
            unless WWW::Battie::Model::DBIC::Content->valid_title($title);
        my $exists = $page_rs->search(
            {
                url => $url,
            }
        );
        my $page = $exists->next;
        if (not $id) {
            # new page
            $self->exception("Argument", "Page '$url' already exists") if $page;
        }
        else {
            if ($page and $page->id != $edit_page->id) {
                $self->exception("Argument", "Page '$url' already exists");
            }
        }
        if ($submit->{preview}) {
            my $textile = $battie->new_textile;
            $textile->disable_html(1);
            my $html = $textile->process($text);
            $data->{cms}->{preview} = 1;
            $data->{cms}->{html} = $html;
            $data->{cms}->{text} = $text;
            $data->{cms}->{url} = $url;
            $data->{cms}->{title} = $title;
            $data->{cms}->{parent} = $parent;
        }
        elsif ($submit->{save}) {
            my $response = $battie->get_response;
            if ($id) {
                $edit_page->title($title);
                $edit_page->text($text);
                $edit_page->update;
                my $ck = "content/pagenavi/$url";
                $battie->delete_cache($ck);
                $response->set_redirect($battie->self_url . '/content/view/' . $url);
            }
            else {
                my $page = $page_rs->create({
                        title => $title,
                        url => $url,
                        text => $text,
                        parent => $parent,
                        ctime => undef,
                    }) or
                    $self->exception("Create", "Could not create page '$title'");
                my $id = $page->id;
                $response->set_redirect($battie->self_url . '/cms/set_page/' . $id);
            }
        }
    }
}

sub system__agb {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    $self->init_db($battie);
    my $schema = $self->schema->{system};
    if ($submit->{add_agb}) {
        $battie->token_exception unless $battie->valid_token;
    }
}

sub cms__edit_motd {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    $self->init_db($battie);
    my $schema = $self->schema->{content};

    my ($id) = @$args;
    my $content = $request->param('content');
    my $start = $request->param('start');
    my $end = $request->param('end');
    my $weight = $request->param('weight') || 1;
    if ($submit->{save}) {
        $battie->require_token;
        for ($start, $end) {
            my ($year, $month, $day, $h, $m, $s);
            if (m/^(\d{4})-(\d{2})-(\d{2})(?: (\d{2}:\d{2}:\d{2}))?\z/) {
                ($year, $month, $day, my $time) = ($1, $2, $3, $4);
                unless ($time) {
                    $time = "00:00:00";
                }
                ($h, $m, $s) = split /:/, $time;
            }
            else {
                $self->exception(Argument => "Invalid date '$_'");
            }
            $_ = DateTime->new(
                year    => $year,
                month   => $month,
                day     => $day,
                hour    => $h,
                minute  => $m,
                second  => $s,
                time_zone => $battie->get_timezone,
            );
            $_->set_time_zone('UTC');
        }
        if ($weight =~ tr/0-9//c or $weight > 1000) {
            $self->exception(Argument => "Invalid weight '$weight'");
        }
        if ($id) {
            my $motd = $schema->resultset('MOTD')->find($id)
                or $self->exception(Argument => "MOTD '$id' does not exist");
            $motd->update({
                    content => $content,
                    weight  => $weight,
                    start   => $start,
                    end     => $end,
                });
        }
        else {
            my $motd = $schema->resultset('MOTD')->create({
                    content => $content,
                    weight  => $weight,
                    start   => $start,
                    end     => $end,
                });
        }
        $battie->set_local_redirect('/cms/list_motd');
    }
    elsif ($submit->{delete}) {
        $battie->require_token;
        my $motd = $schema->resultset('MOTD')->find($id);
        unless ($motd) {
            $self->exception(Argument => "MOTD '$id' does not exist");
        }
        $motd->delete;
        $battie->set_local_redirect('/cms/list_motd');
    }
    my $data = $battie->get_data;
    if ($id) {
        my $motd = $schema->resultset('MOTD')->find($id);
        $self->exception(Argument => "MOTD '$id' does not exist") unless $motd;
        my $ro = $motd->readonly;
        $data->{content}->{motd} = $ro;
    }
}

sub cms__list_motd {
    my ($self, $battie) = @_;
    $battie->response->set_no_cache(1);
    my $request = $battie->get_request;
    my $submit = $request->get_submit;
    my $args = $request->get_args;
    $self->init_db($battie);
    my $schema = $self->schema->{content};
    my $search = $schema->resultset('MOTD')->search({
        });
    my @motds;
    while (my $motd = $search->next) {
        my $ro = $motd->readonly;
        my $re = $battie->get_render->render_message_html($ro->content);
        $ro->set_rendered($re);
        push @motds, $ro;
    }
    my $data = $battie->get_data;
    $data->{motds} = \@motds;
}

1;
